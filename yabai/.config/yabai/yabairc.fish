#!/usr/bin/env fish

# Get the directory where scripts are located
set YABAI_SCRIPTS_DIR "$HOME/.config/yabai/scripts"

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

# global settings
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

set spaces terminal code web work social notes other
set max_spaces (count $spaces)

# Ensure no windows are in native fullscreen (cannot manage/destroy those spaces otherwise)
exit_native_fullscreen_windows

# Force to have only the number of spaces defined in the array
destroy_spaces_beyond_max $max_spaces

# Setup spaces using the list
setup_spaces_with_labels $spaces

# App assignments
echo "Configuring app assignments..."

# Terminal apps
yabai -m rule --add app='^iTerm$' space=terminal
yabai -m rule --add app='^kitty$' space=terminal

# Code editors
yabai -m space code --layout stack
yabai -m rule --add app='^Cursor$' space=code
yabai -m rule --add app='^Zed$' space=code
yabai -m rule --add app='^Code$' space=code
yabai -m rule --add app='^Postman$' space=code

# Web browsers
yabai -m space web --layout stack
yabai -m rule --add app='^Brave Browser$' space=web
yabai -m rule --add app='^Arc$' space=web

# Social and communication apps
yabai -m rule --add app='^(Telegram|WhatsApp|Discord)$' space=social
yabai -m rule --add app=WhatsApp space=social

# Work apps
yabai -m rule --add app='^Fantastical$' space=work
yabai -m rule --add app='^(Slack|Zoom)$' space=work

# Notes
yabai -m rule --add app=Obsidian space=notes

# Media and entertainment
yabai -m rule --add app='^(Music|Spotify)$' space=other
yabai -m rule --add app=Claude space=other

echo "Configuring non-managed apps..."
yabai -m rule --add app='^System Preferences$' sticky=on sub-layer=above manage=off
yabai -m rule --add app='^System Settings$' sticky=on sub-layer=above manage=off
yabai -m rule --add app='^Finder$' manage=off sticky=on sub-layer=above
yabai -m rule --add app='^1Password$' manage=off sticky=on sub-layer=above
yabai -m rule --add app='^System Information$' sticky=on sub-layer=above manage=off
yabai -m rule --add app='^TeamViewer$' sticky=off sub-layer=above manage=off
yabai -m rule --add title='Settings$' manage=off sub-layer=above sticky=on
yabai -m rule --add title='^Preferences$' manage=off sub-layer=above sticky=on
yabai -m rule --add app=CleanShootX manage=off sub-layer=above sticky=on
yabai -m rule --add app='^Brave Browser$' title='(MetaMask|Phantom Wallet)' sub-layer=above manage=off sticky=on
yabai -m rule --add app='^Brave Browser$' title='Sign In' manage=off sub-layer=above sticky=on
yabai -m rule --add app='^IINA$' manage=off sub-layer=above
yabai -m rule --add app='^Docker Desktop$' manage=off sub-layer=above
yabai -m rule --add app='^krisp$' manage=off
yabai -m rule --add app='^Krisp Helper$' manage=off
yabai -m rule --add app='^Activity Monitor$' manage=off
yabai -m rule --add app='^Google Chrome for Testing$' manage=off
yabai -m rule --add app=Raycast manage=off
yabai -m rule --add app=VeraCrypt manage=off
yabai -m rule --add app=Messages manage=off sub-layer=above sticky=on
yabai -m rule --add app=NordVPN manage=off sub-layer=above sticky=on

# Get the directory where event scripts are located
set YABAI_EVENTS_DIR "$HOME/.config/yabai/events"

# Display management signals
yabai -m signal --add event=display_added action="fish $YABAI_EVENTS_DIR/display_added.fish"
yabai -m signal --add event=display_removed action="fish $YABAI_EVENTS_DIR/display_removed.fish"

# Window management signals - Automatically destroy empty spaces
yabai -m signal --add event=space_changed action="fish $YABAI_EVENTS_DIR/cleanup_empty_spaces.fish"
yabai -m signal --add event=window_destroyed action="fish $YABAI_EVENTS_DIR/cleanup_empty_spaces.fish"

# Create spaces dynamically when specific apps open
# Terminal space
yabai -m signal --add event=window_created app='^iTerm$' action="fish $YABAI_EVENTS_DIR/create_space.fish terminal"
yabai -m signal --add event=window_created app='^kitty$' action="fish $YABAI_EVENTS_DIR/create_space.fish terminal"

# Code space (with stack layout)
yabai -m signal --add event=window_created app='^Cursor$' action="fish $YABAI_EVENTS_DIR/create_space.fish code stack"
yabai -m signal --add event=window_created app='^Zed$' action="fish $YABAI_EVENTS_DIR/create_space.fish code stack"
yabai -m signal --add event=window_created app='^Code$' action="fish $YABAI_EVENTS_DIR/create_space.fish code stack"
yabai -m signal --add event=window_created app='^Postman$' action="fish $YABAI_EVENTS_DIR/create_space.fish code stack"

# Web space (with stack layout)
yabai -m signal --add event=window_created app='^Brave Browser$' action="fish $YABAI_EVENTS_DIR/create_space.fish web stack"
yabai -m signal --add event=window_created app='^Arc$' action="fish $YABAI_EVENTS_DIR/create_space.fish web stack"

# Work space
yabai -m signal --add event=window_created app='^Fantastical$' action="fish $YABAI_EVENTS_DIR/create_space.fish work"
yabai -m signal --add event=window_created app='^Slack$' action="fish $YABAI_EVENTS_DIR/create_space.fish work"
yabai -m signal --add event=window_created app='^Zoom$' action="fish $YABAI_EVENTS_DIR/create_space.fish work"

# Social space
yabai -m signal --add event=window_created app='^Telegram$' action="fish $YABAI_EVENTS_DIR/create_space.fish social"
yabai -m signal --add event=window_created app='^WhatsApp$' action="fish $YABAI_EVENTS_DIR/create_space.fish social"
yabai -m signal --add event=window_created app='^Discord$' action="fish $YABAI_EVENTS_DIR/create_space.fish social"

# Notes space
yabai -m signal --add event=window_created app=Obsidian action="fish $YABAI_EVENTS_DIR/create_space.fish notes"

# Other space
yabai -m signal --add event=window_created app='^Music$' action="fish $YABAI_EVENTS_DIR/create_space.fish other"
yabai -m signal --add event=window_created app='^Spotify$' action="fish $YABAI_EVENTS_DIR/create_space.fish other"
yabai -m signal --add event=window_created app=Claude action="fish $YABAI_EVENTS_DIR/create_space.fish other"

# Signals
# yabai -m signal --add event=window_created app="^Obs$" action="yabai -m space --focus obs"

# borders \
#   "active_color=gradient(top_left=0xFF45c4c0,bottom_right=0xFFba3aa5)" \
#   "inactive_color=0x00RRGGBB" \
#   width=2

borders \
    "active_color=gradient(top_left=0xee33ccff,bottom_right=0xee00ff99)" \
    "inactive_color=0xaa595959" \
    width=2 &

echo "Applying rules..."
yabai -m rule --apply
