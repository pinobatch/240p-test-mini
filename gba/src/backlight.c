/*
Backlight zone test for 160p Test Suite
Copyright 2018 Damian Yerrick

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

*/
#include "global.h"
#include <gba_video.h>
#include <gba_input.h>

extern const unsigned char helpsect_backlight_zone_test[];

void activity_backlight_zone(void) {
  unsigned int inverted = 0, hidden = 0, held_keys = 0, sz = 1;
  unsigned int x = 119, y = 79;

  load_common_obj_tiles();
  while (1) {
    read_pad_help_check(helpsect_backlight_zone_test);
    held_keys |= new_keys;
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      return;
    }
    if (cur_keys & KEY_A) {
      if (new_keys & KEY_UP) {
        sz = (sz + 1) & 0x03;
        held_keys &= ~KEY_A;
      }
      if (new_keys & KEY_DOWN) {
        sz = (sz - 1) & 0x03;
        held_keys &= ~KEY_A;
      }
    } else {
      if (held_keys & KEY_A) {
        held_keys &= ~KEY_A;
        hidden = !hidden;
      }
      if ((cur_keys & KEY_UP) && y > 0) {
        y -= 1;
      }
      if ((cur_keys & KEY_DOWN) && y < 159) {
        y += 1;
      }
      if ((cur_keys & KEY_LEFT) && x > 0) {
        x -= 1;
      }
      if ((cur_keys & KEY_RIGHT) && x < 239) {
        x += 1;
      }
    }

    // Draw the sprite
    oam_used = 0;
    if (!hidden) {
      unsigned int i = oam_used;
      SOAM[i].attr0 = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_SQUARE;
      SOAM[i].attr1 = OBJ_X(x) | ATTR1_SIZE_8;
      SOAM[i].attr2 = (sz < 3) ? sz + 0x22 : 1;
      oam_used = i + 1;
    }
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    BG_COLORS[0] = inverted ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    OBJ_COLORS[1] = inverted ? RGB5(0, 0, 0): RGB5(31, 31, 31);
    ppu_copy_oam();
    REG_DISPCNT = MODE_0 | OBJ_ON;
  }
}
