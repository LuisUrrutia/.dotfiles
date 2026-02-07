#!/usr/bin/env fish

# Source required lib functions
set lib_dir "$HOME/.config/yabai/lib"

source "$lib_dir/spaces.fish"
source "$lib_dir/windows.fish"

set SPACE_LABEL $argv[1]
set LAYOUT $argv[2]
set PREFERRED_DISPLAY $argv[3]
set WINDOW_ID $YABAI_WINDOW_ID

# Validate required parameter
if test -z "$SPACE_LABEL"
    echo "Error: Space label is required" >&2
    exit 1
end

# Early window inspection — single query reused for both floating and tab detection.
set -l window_info (yabai -m query --windows --window "$WINDOW_ID" 2>/dev/null)

# If the window is already gone from yabai (absorbed into a native tab group before
# our handler ran), bail out — there's nothing to move or focus.
if test -z "$window_info" -o "$window_info" = "null"
    echo "[On Window Created] Window $WINDOW_ID not found in yabai, skipping (likely absorbed into tab group)"
    exit 0
end

# Floating window detection (yabai#2615): floating/sticky windows like Ghostty's Quick
# Terminal (subrole=AXFloatingWindow) still trigger window_created signals even with
# manage=off rules. Skip them to avoid moving floating overlays to tiled spaces.
set -l is_floating (echo $window_info | jq -r '.["is-floating"] // false')
if test "$is_floating" = "true"
    echo "[On Window Created] Window $WINDOW_ID is floating, skipping (likely Quick Terminal or popup)"
    exit 0
end

# Native tab detection (yabai#68): apps using macOS native tabs fire window_created
# for each tab switch/creation. Yabai rules run before signals, so the window is
# already on the correct space. Detect this early to avoid unnecessary work —
# tab switches are frequent and ensure_space_exists is expensive (multiple yabai queries).
# Moving a tabbed window would displace the entire tab group to another space.
set -l target_index (yabai -m query --spaces | jq -r ".[] | select(.label == \"$SPACE_LABEL\") | .index")
set -l window_space (echo $window_info | jq -r '.space // empty')

if test -n "$window_space" -a "$window_space" = "$target_index"
    echo "[On Window Created] Window $WINDOW_ID already on space $SPACE_LABEL, skipping (likely native tab event)"
    # Refocus the original app window (not the transient tab). yabai may have auto-focused
    # the transient tab in the stack; when it's absorbed, focus would be lost. Explicitly
    # focusing the original window prevents cross-display focus drift.
    # Note: don't filter by is-visible — on multi-display setups, windows on non-focused
    # displays report is-visible=false even though they're physically on screen.
    set -l original_window (yabai -m query --windows --space $window_space | jq -r \
        "[.[] | select(.id != $WINDOW_ID and (.\"is-floating\" | not))] | .[0].id // empty")
    if test -n "$original_window"
        echo "[On Window Created] Refocusing original window $original_window on space $SPACE_LABEL"
        yabai -m window --focus $original_window 2>/dev/null; or true
    end
    exit 0
end

# Secondary tab detection: if the window query returned no space (timing issue with native
# tabs — the window may not have a space assignment yet), check if this is a known
# native-tab app that already has a window on the target space. If so, this is almost
# certainly a tab event and moving/focusing would displace the existing tab group.
if test -z "$window_space" -o "$window_space" = "0"
    set -l window_app (echo $window_info | jq -r '.app // empty' | string lower)
    if test -n "$window_app"
        for tab_app in $NATIVE_TAB_APPS
            if test "$window_app" = "$tab_app" -a -n "$target_index"
                set -l existing (yabai -m query --windows | jq "[.[] | select(.space == $target_index and (.app | ascii_downcase) == \"$tab_app\" and .id != $WINDOW_ID)] | length")
                if test "$existing" -gt 0
                    echo "[On Window Created] Native tab app $window_app already on space $SPACE_LABEL, skipping (tab event, no space assigned yet)"
                    exit 0
                end
            end
        end
    end
end

# Not a tab event — this is a genuinely new window. Ensure the space exists.
echo "[On Window Created] Ensure space $SPACE_LABEL exists"

ensure_space_exists "$SPACE_LABEL" "$LAYOUT"
set ensure_space_exists_code $status
if test $ensure_space_exists_code -eq 1
    echo "Error: Failed to ensure space exists" >&2
    exit 1
end

# If space was created, move it to preferred display
if test $ensure_space_exists_code -eq 2
    echo "[On Window Created] Space $SPACE_LABEL created, moving to display $PREFERRED_DISPLAY"
    move_space_to_display "$SPACE_LABEL" "$PREFERRED_DISPLAY"
end

move_windows_id_to_space "$WINDOW_ID" "$SPACE_LABEL"

# Focus the newly created window
yabai -m window --focus "$WINDOW_ID" 2>/dev/null; or true
