#!/usr/bin/env fish

# Source helper functions
set YABAI_LIB_DIR "$HOME/.config/yabai/lib"
set YABAI_EVENTS_DIR "$HOME/.config/yabai/events"

source "$YABAI_LIB_DIR/windows.fish"
source "$YABAI_LIB_DIR/spaces.fish"
source "$YABAI_LIB_DIR/signals.fish"
source "$YABAI_LIB_DIR/rules.fish"

# =============================================================================
# SPACE CONFIGURATION
# =============================================================================

# Define space mappings: space_name/layout/preferred display/apps...
# Layout can be: bsp (default), stack, float
set -l space_configs \
    'terminal/bsp/1/^(iTerm|kitty)$' \
    'code/stack/1/^(Cursor|Zed|Code)$,^(Postman|Yaak)$' \
    'web/stack/1/^(Brave Browser|Arc)$' \
    'work/bsp/2/^(Fantastical|BusyCal)$,^Slack$,^Zoom$' \
    'social/bsp/2/^(Telegram|Discord)$,WhatsApp$' \
    'notes/bsp/2/^Obsidian$' \
    'other/bsp/2/^(Music|Spotify)$,Claude$'

# Extract space names from configurations
set -l spaces
for config in $space_configs
    set -l parts (string split '/' $config)
    set -a spaces $parts[1]
end

# Ensure no windows are in native fullscreen
exit_native_fullscreen_windows

# Setup spaces with labels
setup_spaces_with_labels $spaces

#set space_arrangements ""
for config in $space_configs
    set -l parts (string split '/' $config)
    set -l space_name $parts[1]
    set -l layout $parts[2]
    set -l preferred_display $parts[3]
    set -l apps (string split ',' $parts[4])

    # Apply window rules to assign apps to this space
    configure_space_layout_and_rules $space_name $layout $apps

    # Move space to preferred display if not the default (1)
    if test "$preferred_display" != "1"
        #set space_arrangements "$space_arrangements$space_name/$preferred_display,"

        move_space_to_display $space_name $preferred_display
    end

    # Register signals to dynamically create space when apps open
    register_signal_to_create_space_on_app_open $space_name $layout $preferred_display $apps

    echo "--------------------------------------------------------"
end

# Force move all existing windows to their assigned spaces
yabai -m rule --apply

# Clean up any empty spaces left over
destroy_empty_spaces

yabai -m signal --add event=display_added action="fish $YABAI_EVENTS_DIR/on_display_added.fish $space_arrangements"
yabai -m signal --add event=display_removed action="fish $YABAI_EVENTS_DIR/on_display_removed.fish"
yabai -m signal --add event=window_destroyed action="fish $YABAI_EVENTS_DIR/on_window_destroyed.fish"
yabai -m signal --add event=system_woke action="fish $YABAI_EVENTS_DIR/on_system_woke.fish"

echo "Configuring non-managed apps..."

# Sticky apps (always on top, visible on all spaces)
apply_sticky_rules \
    '^System Preferences$' \
    '^System Settings$' \
    '^Finder$' \
    '^1Password$' \
    Messages \
    NordVPN

# Unmanaged apps (not tiled but not necessarily sticky)
apply_unmanaged_rules \
    '^System Information$' \
    '^TeamViewer$' \
    CleanShootX \
    '^IINA$' \
    '^Docker Desktop$' \
    '^krisp$' \
    '^Krisp Helper$' \
    '^Activity Monitor$' \
    '^Google Chrome for Testing$' \
    Raycast \
    VeraCrypt

yabai -m rule --add app='^Arc$' manage=on # IDK why but Arc needs this to be managed
yabai -m rule --add app='^Brave Browser$' title="(MetaMask|Phantom Wallet)" sub-layer=above manage=off sticky=on
yabai -m rule --add app='^Brave Browser$' title="Sign In" manage=off sub-layer=above sticky=on

borders \
    "active_color=gradient(top_left=0xee33ccff,bottom_right=0xee00ff99)" \
    "inactive_color=0xaa595959" \
    blacklist="krisp"    \
    width=2 &
