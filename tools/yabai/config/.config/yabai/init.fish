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

# Define space mappings as JSON records (safer than delimiter parsing).
# Layout can be: bsp (default), stack, float
set -l space_configs_json '[
  {
    "name": "terminal",
    "layout": "stack",
    "preferred_display": 1,
    "apps": ["^Ghostty$"]
  },
  {
    "name": "code",
    "layout": "stack",
    "preferred_display": 1,
    "apps": ["^(Cursor|Zed|Code)$", "^(Postman|Yaak)$"]
  },
  {
    "name": "web",
    "layout": "stack",
    "preferred_display": 1,
    "apps": ["^Brave Browser$"]
  },
  {
    "name": "work",
    "layout": "bsp",
    "preferred_display": 2,
    "apps": ["^(Fantastical|BusyCal)$", "^Slack$", "^Zoom$"]
  },
  {
    "name": "social",
    "layout": "bsp",
    "preferred_display": 2,
    "apps": ["^(Telegram|Discord)$", "WhatsApp$"]
  },
  {
    "name": "notes",
    "layout": "bsp",
    "preferred_display": 2,
    "apps": ["^Obsidian$"]
  },
  {
    "name": "other",
    "layout": "bsp",
    "preferred_display": 2,
    "apps": ["^(Music|Spotify)$", "Claude$"]
  }
]'

# Extract space names from configuration records
set -l spaces (printf '%s\n' "$space_configs_json" | jq -r '.[].name')

# Ensure no windows are in native fullscreen
exit_native_fullscreen_windows

# Setup spaces with labels
setup_spaces_with_labels $spaces

set -l space_arrangements ""
for config in (printf '%s\n' "$space_configs_json" | jq -c '.[]')
    set -l space_name (printf '%s\n' "$config" | jq -r '.name')
    set -l layout (printf '%s\n' "$config" | jq -r '.layout')
    set -l preferred_display (printf '%s\n' "$config" | jq -r '.preferred_display')
    set -l apps (printf '%s\n' "$config" | jq -r '.apps[]')

    # Apply window rules to assign apps to this space
    configure_space_layout_and_rules $space_name $layout $apps

    # Move space to preferred display if not the default (1)
    if test "$preferred_display" != "1"
        set space_arrangements "$space_arrangements$space_name/$preferred_display,"
        move_space_to_display $space_name $preferred_display
    end

    # Register signals to dynamically create space when apps open
    register_signal_to_create_space_on_app_open $space_name $layout $preferred_display $apps

    echo "--------------------------------------------------------"
end

# Force move all existing windows to their assigned spaces
yabai -m rule --apply

# Wait for rules to finish applying before cleanup
# rule --apply is async, windows need time to move to assigned spaces
sleep 1

# Clean up any empty spaces left over
destroy_empty_spaces

yabai -m signal --add event=display_added action="fish $YABAI_EVENTS_DIR/on_display_added.fish $space_arrangements"
yabai -m signal --add event=display_removed action="fish $YABAI_EVENTS_DIR/on_display_removed.fish"
yabai -m signal --add event=window_destroyed action="fish $YABAI_EVENTS_DIR/on_window_destroyed.fish"
# Native tab refocus: when Ghostty creates/absorbs a tab, yabai briefly focuses the
# transient window then loses focus (drifts to another display). These deferred handlers
# wait for the dust to settle, then force focus back on the main Ghostty window.
yabai -m signal --add event=window_created app="^Ghostty\$" action="fish $YABAI_EVENTS_DIR/on_ghostty_created.fish"
yabai -m signal --add event=window_destroyed app="^Ghostty\$" action="fish $YABAI_EVENTS_DIR/on_ghostty_destroyed.fish"
yabai -m signal --add event=system_woke action="fish $YABAI_EVENTS_DIR/on_system_woke.fish"
yabai -m signal --add event=space_changed action="fish $YABAI_EVENTS_DIR/on_space_changed.fish"

# BusyCal/Slack resize signals - resize BusyCal when both apps are on work space
yabai -m signal --add event=window_created app="^BusyCal\$" action="fish $YABAI_EVENTS_DIR/on_busycal_slack_created.fish"
yabai -m signal --add event=window_created app="^Slack\$" action="fish $YABAI_EVENTS_DIR/on_busycal_slack_created.fish"

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
    'CleanShot X' \
    '^IINA$' \
    '^Docker Desktop$' \
    '^krisp$' \
    '^Krisp Helper$' \
    '^Activity Monitor$' \
    '^Google Chrome for Testing$' \
    Raycast \
    VeraCrypt

yabai -m rule --add app='^Ghostty$' subrole='AXFloatingWindow' manage=off
yabai -m rule --add app='^Brave Browser$' title="(MetaMask|Phantom Wallet)" sub-layer=above manage=off sticky=on
yabai -m rule --add app='^Brave Browser$' title="Sign In" manage=off sub-layer=above sticky=on

# Save expected display count for smart wake detection (yabai#259).
# on_system_woke.fish compares this against actual count to decide if a full
# restart is needed, avoiding unnecessary restarts on brief lock/unlock.
yabai -m query --displays | jq 'length' > /tmp/yabai_expected_displays

borders \
    "active_color=gradient(top_left=0xee33ccff,bottom_right=0xee00ff99)" \
    "inactive_color=0xaa595959" \
    blacklist="krisp"    \
    width=2 &
