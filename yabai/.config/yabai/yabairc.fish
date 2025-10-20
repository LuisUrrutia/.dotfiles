#!/usr/bin/env fish

# Source helper functions
source (dirname (status --current-filename))/yabai_functions.fish

# for this to work you must configure sudo such that
# it will be able to run the command without password
#
# see this wiki page for information:
#  - https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)#configure-scripting-addition
#
yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
sudo yabai --load-sa

# Global settings
yabai -m config \
    external_bar off:40:0 \
    menubar_opacity 1.0 \
    mouse_follows_focus on \
    focus_follows_mouse off \
    display_arrangement_order default \
    window_origin_display default \
    window_placement second_child \
    window_insertion_point focused \
    window_zoom_persist on \
    window_shadow off \
    window_animation_duration 0.0 \
    window_animation_easing ease_out_circ \
    window_opacity_duration 0.0 \
    active_window_opacity 1.0 \
    normal_window_opacity 0.90 \
    window_opacity off \
    insert_feedback_color 0xffd75f5f \
    split_ratio 0.50 \
    split_type auto \
    auto_balance off \
    top_padding 0 \
    bottom_padding 1 \
    left_padding 1 \
    right_padding 1 \
    window_gap 1 \
    layout bsp \
    mouse_modifier fn \
    mouse_action1 move \
    mouse_action2 resize \
    mouse_drop_action swap

# =============================================================================
# SPACE CONFIGURATION
# =============================================================================

# Define space mappings: space_name|layout|apps...
# Layout can be: bsp (default), stack, float
# Apps are separated by spaces (use regex patterns as needed)
set -l space_configs \
    'terminal|bsp|^iTerm$ ^kitty$' \
    'code|stack|^Cursor$ ^Zed$ ^Code$ ^Postman$' \
    'web|stack|^Brave\ Browser$ ^Arc$' \
    'work|bsp|^Fantastical$ ^Slack$ ^Zoom$' \
    'social|bsp|^Telegram$ ^WhatsApp$ ^Discord$ WhatsApp' \
    'notes|bsp|Obsidian' \
    'other|bsp|^Music$ ^Spotify$ Claude'

# Extract space names from configurations
set -l spaces
for config in $space_configs
    set -l parts (string split '|' $config)
    set -a spaces $parts[1]
end

set max_spaces (count $spaces)

# Ensure no windows are in native fullscreen
exit_native_fullscreen_windows

# Force to have only the number of spaces defined
destroy_spaces_beyond_max $max_spaces

# Setup spaces with labels
setup_spaces_with_labels $spaces

# =============================================================================
# APPLY RULES AND SIGNALS
# =============================================================================

echo "Configuring app assignments and signals..."

for config in $space_configs
    set -l parts (string split '|' $config)
    set -l space_name $parts[1]
    set -l layout $parts[2]
    set -l apps (string split ' ' $parts[3])

    # Apply window rules to assign apps to this space
    apply_window_rules_for_space $space_name $layout $apps

    # Register signals to dynamically create space when apps open
    register_window_created_signals_for_space $space_name $layout $apps
end

# =============================================================================
# NON-MANAGED APPS
# =============================================================================

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

# Title-based rules
apply_title_rule '^Brave Browser$' '(MetaMask|Phantom Wallet)' off on above
apply_title_rule '^Brave Browser$' 'Sign In' off on above
apply_title_rule '' 'Settings$' off on above
apply_title_rule '' '^Preferences$' off on above

# =============================================================================
# DISPLAY MANAGEMENT SIGNALS
# =============================================================================

set YABAI_EVENTS_DIR "$HOME/.config/yabai/events"

yabai -m signal --add event=display_added action="fish $YABAI_EVENTS_DIR/display_added.fish"
yabai -m signal --add event=display_removed action="fish $YABAI_EVENTS_DIR/display_removed.fish"

# Window management signals - Automatically destroy empty spaces
yabai -m signal --add event=space_changed action="fish $YABAI_EVENTS_DIR/cleanup_empty_spaces.fish"
yabai -m signal --add event=window_destroyed action="fish $YABAI_EVENTS_DIR/cleanup_empty_spaces.fish"

# =============================================================================
# BORDERS
# =============================================================================

borders \
    "active_color=gradient(top_left=0xee33ccff,bottom_right=0xee00ff99)" \
    "inactive_color=0xaa595959" \
    width=2 &

echo "Applying rules..."
yabai -m rule --apply
