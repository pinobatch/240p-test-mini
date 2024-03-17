/*
Overscan test for 160p Test Suite
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
#include <gba_input.h>
#include <gba_video.h>
#include <stdint.h>

#define PFMAP 23

static signed int keys_to_side(unsigned int keys) {
  if (keys & KEY_DOWN) return 3;
  if (keys & KEY_UP) return 2;
  if (keys & KEY_LEFT) return 1;
  if (keys & KEY_RIGHT) return 0;
  return -1;
}

static const unsigned char overscan_dist_x[4] = {
  23, 5, 14, 14
};
static const unsigned char overscan_dist_y[4] = {
  9, 9, 5, 13
};

static void overscan_draw_arrow(unsigned int side, unsigned int dist) {
  unsigned int i = oam_used;
  unsigned int x = 116, y = 76;
  unsigned int tilenum = (side & 0x02) ? 0x0009 : 0x0008;
  switch (side) {
    case 0:  // R
    x = 224 - dist;
    break;
    case 1:  // L
    x = dist;
    break;
    case 2:  // U
    y = dist;
    break;
    case 3:  // D
    y = 144 - dist;
    break;
  }
  SOAM[i].attr0 = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_SQUARE;
  SOAM[i].attr1 = OBJ_X(x) | OBJ_HFLIP | OBJ_VFLIP;
  SOAM[i].attr2 = tilenum;
  if (side & 0x02) {
    y += 8;
  } else {
    x += 8;
  }
  SOAM[i + 1].attr0 = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_SQUARE;
  SOAM[i + 1].attr1 = OBJ_X(x);
  SOAM[i + 1].attr2 = tilenum;
  oam_used = i + 2;
}

void activity_overscan() {
  unsigned char dist[4] = {2, 2, 2, 2};
  unsigned int side = 0, inverted = 0;

  load_common_obj_tiles();
  load_common_bg_tiles();
  // Make all BG tiles opaque
  for (uint32_t *c = PATRAM4(0, 0); c < PATRAM4(0, 32); ++c) {
    *c |= 0x44444444;
  }
  dma_memset16(MAP[PFMAP], 0x0004, 32*20*2);

  while (1) {
    read_pad_help_check(helpsect_overscan);
    autorepeat(KEY_RIGHT|KEY_LEFT|KEY_UP|KEY_DOWN);
    signed int new_side = keys_to_side(new_keys);
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      return;
    }
    if (cur_keys & KEY_A) {
      if (new_side >= 0) {
        unsigned int holddir = new_side ^ side;
        if (holddir == 0 && dist[side] > 0) {  // decrease
          dist[side] -= 1;
        } else if (holddir == 1 && dist[side] < 24) {
          dist[side] += 1;
        }
      }
    } else if (new_side >= 0) {
      side = new_side;
    }
    
    oam_used = 0;
    overscan_draw_arrow(side, dist[side]);
    ppu_clear_oam(oam_used);
    
    VBlankIntrWait();
    // Color 0: outside
    BG_COLORS[0] = BG_COLORS[5] = inverted ? RGB5(0, 0, 0) : RGB5(31, 31, 31);
    BG_COLORS[4] = inverted ? RGB5(23, 23, 23) : RGB5(15, 15, 15);
    if (cur_keys & KEY_A) {
      OBJ_COLORS[2] = inverted ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    } else {
      OBJ_COLORS[2] = inverted ? RGB5(15, 15, 15) : RGB5(23, 23, 23);
    }
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    ppu_copy_oam();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON | WIN0_ON;
    REG_WINOUT = 0x10;  // BG0 inside, BG1 outside
    REG_WININ = 0x11;
    // start<<8 | end
    REG_WIN0H = (dist[1] << 8) | ((240 - dist[0]) & 0xFF);
    REG_WIN0V = (dist[2] << 8) | ((160 - dist[3]) & 0xFF);
    
    for (int i = 0; i < 4; ++i) {
      unsigned int x = overscan_dist_x[i];
      unsigned int y = overscan_dist_y[i];
      unsigned int value = dist[i];
      unsigned int tens = value / 10;
      MAP[PFMAP][y][x] = tens ? (0x0010 + tens) : 0x0004;
      MAP[PFMAP][y][x + 1] = 0x0010 + (value - tens * 10);
      MAP[PFMAP][y + 1][x] = 0x0006;
      MAP[PFMAP][y + 1][x + 1] = 0x0007;
    }
  }

  lame_boy_demo();
}
