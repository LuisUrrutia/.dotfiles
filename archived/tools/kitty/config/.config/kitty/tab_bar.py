from datetime import datetime, timezone
import math
import os
import sys
import locale

from collections.abc import Sequence
from functools import partial
from zoneinfo import ZoneInfo

from kitty.borders import Border
from kitty.boss import get_boss
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import DrawData, ExtraData, TabBar, TabBarData, as_rgb, color_as_int, draw_title

class WeirdTabBar(TabBar):
    def __init__(self, tab_bar: TabBar):
        self.inner = tab_bar

    def __getattr__(self, attr):
        return getattr(self.inner, attr)

    def __setattr__(self, attr, value):
        if attr == 'draw_data':
            return self.inner.__setattr__(attr, value)
        else:
            return super().__setattr__(attr, value)

    def destroy(self) -> None:
        self.inner.screen.reset_callbacks()
        del self.inner.screen

    def update(self, data: Sequence[TabBarData]) -> None:
        right_text = _get_date_text()
        left_logo = _get_logo()

        opts = get_options()
        screen = self.inner.screen
        orig_align = self.inner.align

        match opts.tab_bar_align:
            case "left":
                self.inner.align: Callable[[], None] = partial(self.pad_left, len(left_logo))
            case "right":
                self.inner.align: Callable[[], None] = partial(self.pad_right, len(right_text))

        self.inner.update(data)

        screen.cursor.x = max(0, screen.columns - len(right_text) - 3)
        screen.cursor.fg = as_rgb(int(opts.foreground))
        screen.cursor.bg = as_rgb(int(self.draw_data.default_bg))
        _draw_right(right_text, screen, self.draw_data.active_bg)

        screen.cursor.x = 0
        screen.cursor.fg = as_rgb(int(self.draw_data.active_bg))
        screen.cursor.bg = as_rgb(int(self.draw_data.default_bg))
        _draw_left(left_logo, screen, as_rgb(int(opts.foreground)))

        self.inner.align = orig_align

    def pad_left(self, padding: int) -> None:
        self.screen.cursor.x = 0
        self.screen.insert_characters(padding)
        self.inner.cell_ranges = [(s + padding, e + padding) for (s, e) in self.inner.cell_ranges]

    def pad_right(self, padding: int) -> None:
        if not self.inner.cell_ranges:
            return
        end = self.inner.cell_ranges[-1][1]
        if end < self.screen.columns - padding - 1:
            shift = self.screen.columns - end - padding
            self.screen.cursor.x = 0
            self.screen.insert_characters(shift)
            self.inner.cell_ranges = [(s + shift, e + shift) for (s, e) in self.inner.cell_ranges]

def _get_date_text() -> str:
    clock = datetime.now().strftime("%d/%m %H:%M")
    chile = datetime.now(ZoneInfo("America/Santiago")).strftime("(CL %H:%M)")
    utc = datetime.now(timezone.utc).strftime("(UTC %H:%M)")

    return clock + ' ' + chile + ' ' + utc

def _get_logo() -> str:
    return " 󰀵  "

def _draw_tab(
    draw_data: DrawData, screen: Screen, tab: TabBarData,
    before: int, max_tab_length: int, index: int, is_last: bool,
    extra_data: ExtraData
) -> int:
    original_fg = screen.cursor.fg
    left_sep, right_sep = ('', '')
    slant_fg = as_rgb(color_as_int(draw_data.default_bg))

    # Hack to draw the rounded corner of the tab
    def draw_sep(which: str) -> None:
        # Since we are drawing a character as the rounded corner of the tab (hack)
        # we need to set the fg color to the tab background color
        tab_bg = as_rgb(draw_data.tab_bg(tab))
        screen.cursor.fg = tab_bg
        screen.cursor.bg = slant_fg
        screen.draw(which)

        # Restore original cursor colors
        screen.cursor.bg = tab_bg
        screen.cursor.fg = original_fg

    # TODO: logic based on max title length?
    max_tab_length += 1
    if max_tab_length <= 1:
        screen.draw('…')
    elif max_tab_length == 2:
        screen.draw('…|')
    elif max_tab_length < 6:
        draw_sep(left_sep)
        screen.draw('…')
        draw_sep(right_sep)
    else:
        draw_sep(left_sep)
        draw_title(draw_data, screen, tab, index, max_tab_length)
        extra = screen.cursor.x - before - max_tab_length
        if extra >= 0:
            screen.cursor.x -= extra + 3
            screen.draw('…')
        elif extra == -1:
            screen.cursor.x -= 2
            screen.draw('…')
        draw_sep(right_sep)

    if not is_last:
        draw_sep(' ')

    return screen.cursor.x

def _draw_left(logo: str, screen: Screen, default_fg):
    screen.draw(logo)
    screen.cursor.fg = default_fg
    screen.cursor.dim = True
    screen.cursor.bold = False
    screen.cursor.italic = False
    screen.cursor.strikethrough = False
    screen.cursor.dim = False
    # screen.cursor.x = len(logo)

    return screen.cursor.x

def _draw_right(text: str, screen: Screen, active_bg):
    screen.cursor.dim = True
    screen.cursor.bold = False
    screen.cursor.italic = False
    screen.cursor.strikethrough = False
    screen.draw(text)
    screen.cursor.dim = False
    screen.cursor.fg = as_rgb(int(active_bg))
    screen.draw("  ")

def draw_tab(
    draw_data: DrawData, screen: Screen, tab: TabBarData,
    before: int, max_title_length: int, index: int, is_last: bool,
    extra_data: ExtraData
) -> int:
    tm = get_boss().active_tab_manager
    if type(tm.tab_bar) is not WeirdTabBar:
        tm.tab_bar = WeirdTabBar(tm.tab_bar)

    end = _draw_tab(draw_data, screen, tab, before, max_title_length, index, is_last, extra_data)

    return end
