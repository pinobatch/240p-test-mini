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
  (SCREEN_WIDTH >> 3) - 5 - 2, 5, ((SCREEN_WIDTH >> 3) - 1) / 2, ((SCREEN_WIDTH >> 3) - 1) / 2
};
static const unsigned char overscan_dist_y[4] = {
  ((SCREEN_HEIGHT >> 3) - 1) / 2, ((SCREEN_HEIGHT >> 3) - 1) / 2, 5, (SCREEN_HEIGHT >> 3) - 5 - 2
};

static void overscan_draw_arrow(unsigned int side, unsigned int dist) {
  unsigned int i = oam_used;
  unsigned int x = ((SCREEN_WIDTH - 8) / 2), y = ((SCREEN_HEIGHT - 8) / 2);
  unsigned int tilenum = (side & 0x02) ? 0x0009 : 0x0008;
  switch (side) {
    case 0:  // R
    x = (SCREEN_WIDTH - 16) - dist;
    break;
    case 1:  // L
    x = dist;
    break;
    case 2:  // U
    y = dist;
    break;
    case 3:  // D
    y = (SCREEN_HEIGHT - 16) - dist;
    break;
    default:
    break;
  }
  SOAM[i].attr0 = OBJ_Y(y) | ATTR0_COLOR_16 | ATTR0_SQUARE;
  SOAM[i].attr1 = OBJ_X(x) | ATTR1_FLIP_X | ATTR1_FLIP_Y;
  SOAM[i].attr2 = tilenum;
  if (side & 0x02) {
    y += 8;
  } else {
    x += 8;
  }
  SOAM[i + 1].attr0 = OBJ_Y(y) | ATTR0_COLOR_16 | ATTR0_SQUARE;
  SOAM[i + 1].attr1 = OBJ_X(x);
  SOAM[i + 1].attr2 = tilenum;
  oam_used = i + 2;
}

void activity_overscan() {
  unsigned char dist[4] = {2, 2, 2, 2};
  unsigned int side = 0, inverted = 0;
  unsigned int y_win_value = 0;

  load_common_obj_tiles();
  load_common_bg_tiles();
  // Make all BG tiles opaque
  for (uint32_t *c = PATRAM4(0, 0); c < PATRAM4(0, 32); ++c) {
    *c |= 0x44444444;
  }
  dma_memset16(MAP[PFMAP], 0x0004, 32*(SCREEN_HEIGHT >> 3)*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  // Make all BG tiles opaque
  for (uint32_t *c = PATRAM4_SUB(0, 0); c < PATRAM4_SUB(0, 32); ++c) {
    *c |= 0x44444444;
  }
  dma_memset16(MAP_SUB[PFMAP], 0x0004, 32*(SCREEN_HEIGHT >> 3)*2);
  #endif

  while (1) {
    read_pad_help_check(helpsect_overscan);
    autorepeat(KEY_RIGHT|KEY_LEFT|KEY_UP|KEY_DOWN);
    signed int new_side = keys_to_side(new_keys);
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      REG_DMA0CNT = 0;
      REG_DMA1CNT = 0;
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
    BG_PALETTE[0] = BG_PALETTE[5] = inverted ? RGB5(0, 0, 0) : RGB5(31, 31, 31);
    BG_PALETTE[4] = inverted ? RGB5(23, 23, 23) : RGB5(15, 15, 15);
    if (cur_keys & KEY_A) {
      SPRITE_PALETTE[2] = inverted ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    } else {
      SPRITE_PALETTE[2] = inverted ? RGB5(15, 15, 15) : RGB5(23, 23, 23);
    }
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    // Color 0: outside
    BG_PALETTE_SUB[0] = BG_PALETTE_SUB[5] = inverted ? RGB5(0, 0, 0) : RGB5(31, 31, 31);
    BG_PALETTE_SUB[4] = inverted ? RGB5(23, 23, 23) : RGB5(15, 15, 15);
    if (cur_keys & KEY_A) {
      SPRITE_PALETTE_SUB[2] = inverted ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    } else {
      SPRITE_PALETTE_SUB[2] = inverted ? RGB5(15, 15, 15) : RGB5(23, 23, 23);
    }
    BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET_SUB[0].x = BG_OFFSET_SUB[0].y = 0;
    #endif
    ppu_copy_oam();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON | WIN0_ON | WIN1_ON | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_WINOUT = 0x10;  // BG0 inside, BG1 outside
    REG_WININ = 0x1111;

    // start<<8 | end
    // Do this with the y value to fix an NDS bug.
    // This doesn't create issues on the GBA, while sharing the code
    y_win_value = (dist[2] << 8) | ((SCREEN_HEIGHT - dist[3]) & 0xFF) | (((dist[2] << 8) | ((SCREEN_HEIGHT - dist[3]) & 0xFF)) << 16);
    unsigned int y_set_value = (7 << 8) | ((SCREEN_HEIGHT - dist[3]) & 0xFF);
    if(dist[2] == 0)
        y_set_value = ((SCREEN_HEIGHT - dist[3]) & 0xFF);
    
    REG_WIN0H = (dist[1] << 8) | (SCREEN_WIDTH / 2);
    REG_WIN0V = y_set_value;
    // NDS requires two windows to fill 256 pixels on the X axys
    REG_WIN1H = ((SCREEN_WIDTH / 2) << 8) | ((SCREEN_WIDTH - dist[0]) & 0xFF);
    REG_WIN1V = y_set_value;
  
    REG_DMA0CNT = 0;
    #ifdef __NDS__
    DMA_FILL(0) = y_win_value;
    REG_DMA0SAD = (intptr_t)&(DMA_FILL(0));
    #else
    REG_DMA0SAD = (intptr_t)&(y_win_value);
    #endif
    REG_DMA0DAD = (intptr_t)&(REG_WIN0V);
    REG_DMA0CNT = 1|DMA_DST_FIXED|DMA_SRC_FIXED|DMA32|DMA_HBLANK|DMA_ENABLE;

    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON | WIN0_ON | WIN1_ON | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_WINOUT_SUB = 0x10;  // BG0 inside, BG1 outside
    REG_WININ_SUB = 0x1111;
    
    REG_WIN0H_SUB = (dist[1] << 8) | (SCREEN_WIDTH / 2);
    REG_WIN0V_SUB = y_set_value;
    // NDS requires two windows to fill 256 pixels on the X axys
    REG_WIN1H_SUB = ((SCREEN_WIDTH / 2) << 8) | ((SCREEN_WIDTH - dist[0]) & 0xFF);
    REG_WIN1V_SUB = y_set_value;
  
    REG_DMA1CNT = 0;
    REG_DMA1SAD = (intptr_t)&(DMA_FILL(0));
    REG_DMA1DAD = (intptr_t)&(REG_WIN0V_SUB);
    REG_DMA1CNT = 1|DMA_DST_FIXED|DMA_SRC_FIXED|DMA32|DMA_HBLANK|DMA_ENABLE;
    #endif
    
    for (int i = 0; i < 4; ++i) {
      unsigned int x = overscan_dist_x[i];
      unsigned int y = overscan_dist_y[i];
      unsigned int value = dist[i];
      unsigned int tens = value / 10;
      MAP[PFMAP][y][x] = tens ? (0x0010 + tens) : 0x0004;
      MAP[PFMAP][y][x + 1] = 0x0010 + (value - tens * 10);
      MAP[PFMAP][y + 1][x] = 0x0006;
      MAP[PFMAP][y + 1][x + 1] = 0x0007;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      MAP_SUB[PFMAP][y][x] = tens ? (0x0010 + tens) : 0x0004;
      MAP_SUB[PFMAP][y][x + 1] = 0x0010 + (value - tens * 10);
      MAP_SUB[PFMAP][y + 1][x] = 0x0006;
      MAP_SUB[PFMAP][y + 1][x + 1] = 0x0007;
      #endif
    }
  }

  lame_boy_demo();
}
