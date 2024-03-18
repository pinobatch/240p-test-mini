/*
Scroll tests for 160p Test Suite
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
#include "kikitiles_chr.h"
#include "kikimap_chr.h"
#include "greenhillzone_chr.h"

#define PFSCROLLTEST 22
#define BFISCROLLTEST 21

enum scrolleffect_e {
    SCROLLEFFECT_NONE = 0,
    SCROLLEFFECT_HALF = 1,
    SCROLLEFFECT_BFI = 2
};

typedef enum scrolleffect_e scrolleffect;

extern bool flashing_accepted;

static unsigned short scrolltest_y;
static unsigned char scrolltest_dy;
static unsigned char scrolltest_dir;
static unsigned char scrolltest_pause;

void activity_grid_scroll(void) {
  unsigned int inverted = 0;
  unsigned int held_keys = 0;
  unsigned int x = 0, y = 0;
  
  scrolltest_dir = KEY_RIGHT;
  scrolltest_pause = 0;
  scrolltest_dy = 1;

  load_common_bg_tiles();
  dma_memset16(MAP[PFSCROLLTEST], 0x0020, 32*32*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(MAP_SUB[PFSCROLLTEST], 0x0020, 32*32*2);
  #endif
  do {
    read_pad_help_check(helpsect_grid_scroll_test);
    held_keys |= new_keys;
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (cur_keys & KEY_A) {
      // A + direction (not diagonal): change direction
      unsigned int newdir = new_keys & (KEY_UP | KEY_DOWN | KEY_LEFT | KEY_RIGHT);
      if (newdir) {
        scrolltest_dir = newdir;
        held_keys &= ~KEY_A;
      }
    } else {
      if (held_keys & KEY_A) {
        scrolltest_pause = !scrolltest_pause;
        held_keys &= ~KEY_A;
      }
      if ((new_keys & KEY_UP) && scrolltest_dy < 4) {
        ++scrolltest_dy;
      }
      if ((new_keys & KEY_DOWN) && scrolltest_dy > 1) {
        --scrolltest_dy;
      }
    }

    if (scrolltest_pause) {
    
    } else if (scrolltest_dir & KEY_LEFT) {
      x -= scrolltest_dy;
    } else if (scrolltest_dir & KEY_RIGHT) {
      x += scrolltest_dy;
    } else if (scrolltest_dir & KEY_UP) {
      y -= scrolltest_dy;
    } else if (scrolltest_dir & KEY_DOWN) {
      y += scrolltest_dy;
    }
    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
    BG_OFFSET[0].x = x;
    BG_OFFSET[0].y = y;
    BG_PALETTE[0] = inverted ? RGB5(31,31,31) : RGB5(0, 0, 0);
    BG_PALETTE[1] = inverted ? RGB5(0, 0, 0) : RGB5(31,31,31);
    REG_DISPCNT = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
    BG_OFFSET_SUB[0].x = x;
    BG_OFFSET_SUB[0].y = y;
    BG_PALETTE_SUB[0] = inverted ? RGB5(31,31,31) : RGB5(0, 0, 0);
    BG_PALETTE_SUB[1] = inverted ? RGB5(0, 0, 0) : RGB5(31,31,31);
    REG_DISPCNT_SUB = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
    #endif
  } while (!(new_keys & KEY_B));
}

// Game-like scroll tests ///////////////////////////////////////////

static void move_1d_scroll(void) {
  if (new_keys & (KEY_LEFT | KEY_RIGHT)) {
    scrolltest_dir = !scrolltest_dir;
  }
  if (new_keys & KEY_A) {
    scrolltest_pause = !scrolltest_pause;
  }
  if ((new_keys & KEY_UP) && scrolltest_dy < 16) {
    ++scrolltest_dy;
  }
  if ((new_keys & KEY_DOWN) && scrolltest_dy > 1) {
    --scrolltest_dy;
  }
  if (scrolltest_pause) {
    
  } else if (scrolltest_dir) {
    scrolltest_y -= scrolltest_dy;
  } else {
    scrolltest_y += scrolltest_dy;
  }
}

// Vertical scroll (like Kiki Kaikai) ///////////////////////////////

/*
This uses a 16x16-pixel metatile engine and an autotiler to draw
the wall shadow shapes.

Metatiles 1-3 use palette 1 instead of 0.
*/
static const unsigned char metatiles[][4] = {
  {0x00,0x02,0x02,0x00},  // 0: sand
  {0x04,0x06,0x05,0x07},  // 1: path
  {0x01,0x03,0x01,0x03},  // 2: wall top
  {0x0c,0x0e,0x0d,0x0f},  // 3: wall front
  {0x11,0x13,0x02,0x00},  // 4: wall shadow (top right corner)
  {0x13,0x13,0x02,0x00},  // 5: wall shadow (top)
  {0x13,0x02,0x02,0x00},  // 6: wall shadow (top left corner)
  {0x13,0x02,0x13,0x00},  // 7: wall shadow (left)
  {0x12,0x02,0x13,0x00},  // 8: wall shadow (bottom left corner)
  {0x13,0x13,0x13,0x00},  // 9: wall shadow (top and left)
};
static const unsigned char mt_below[] = {
  0, 0, 3, 4, 0, 0, 0, 6, 6, 6
};
static const unsigned char mt_belowR[] = {
  8, 0, 3, 9, 0, 0, 0, 7, 7, 7
};

static const unsigned short kikipalette0[] = {
  RGB5( 0, 0, 0),RGB5(15,11, 7),RGB5(23,18,13),RGB5(31,25,19)
};
static const unsigned short kikipalette1[] = {
  RGB5( 0, 0, 0),RGB5(18,18,18),RGB5(0, 25, 0),RGB5(25,25,25)
};

static void load_bfi_bg(void) {
  dma_memset16(PATRAM4(0, 0xC0), 0x1111, 32);
  dma_memset16(MAP[BFISCROLLTEST], 0xF0C0, 32*32*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(PATRAM4_SUB(0, 0xC0), 0x1111, 32);
  dma_memset16(MAP_SUB[BFISCROLLTEST], 0xF0C0, 32*32*2);
  #endif
}

static void load_kiki_bg(void) {
  bitunpack2(PATRAM4(0, 0), kikitiles_chrTiles, sizeof(kikitiles_chrTiles));
  dma_memset16(MAP[PFSCROLLTEST], 0x0000, 32*64*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  bitunpack2(PATRAM4_SUB(0, 0), kikitiles_chrTiles, sizeof(kikitiles_chrTiles));
  dma_memset16(MAP_SUB[PFSCROLLTEST], 0x0000, 32*64*2);
  #endif
  load_bfi_bg();
  char metatile_buffer[16];
  for(int i = 0; i < 16; i++)
    metatile_buffer[i] = 0; // Clear metatile buffer

  for (unsigned int y = 0; y < 32; ++y) {
    // Decode one row
    unsigned int tiletotopleft = 0;
    unsigned int tiletoleft = 0;

    // Run Markov chain: guess the most common tile below each
    for (unsigned int x = 0; x < 16; x++) {
      unsigned int tilethere = metatile_buffer[x];
      if (tiletoleft == 3) {
        // To the right of a wall, different rules apply
        tiletoleft = mt_belowR[tilethere];
      } else {
        tiletoleft = mt_below[tilethere];
        if (tiletoleft == 4 && tiletotopleft == 3) {
          tiletoleft = 5;
        }
      }
      tiletotopleft = tilethere;
      metatile_buffer[x] = tiletoleft;
    }
    
    // Replace with path from replaceloop
    unsigned int wallbits = kikimap_chrTiles[y];
    for (unsigned int x = 0; x < 16 && wallbits; ++x) {
      unsigned int replacement = wallbits & 0x03;
      if (replacement) metatile_buffer[x] = replacement;
      wallbits >>= 2;
    }

    // Render metatile row
    for (unsigned int x = 0; x < 16; ++x) {
      unsigned int mtid = metatile_buffer[x];
      unsigned int attr = (mtid >= 1 && mtid <= 3) ? 0x1000 : 0x0000;
      MAP[PFSCROLLTEST][y * 2    ][x * 2    ] = metatiles[mtid][0] | attr;
      MAP[PFSCROLLTEST][y * 2    ][x * 2 + 1] = metatiles[mtid][1] | attr;
      MAP[PFSCROLLTEST][y * 2 + 1][x * 2    ] = metatiles[mtid][2] | attr;
      MAP[PFSCROLLTEST][y * 2 + 1][x * 2 + 1] = metatiles[mtid][3] | attr;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      MAP_SUB[PFSCROLLTEST][y * 2    ][x * 2    ] = metatiles[mtid][0] | attr;
      MAP_SUB[PFSCROLLTEST][y * 2    ][x * 2 + 1] = metatiles[mtid][1] | attr;
      MAP_SUB[PFSCROLLTEST][y * 2 + 1][x * 2    ] = metatiles[mtid][2] | attr;
      MAP_SUB[PFSCROLLTEST][y * 2 + 1][x * 2 + 1] = metatiles[mtid][3] | attr;
      #endif
    }
  }
  // This map is a PITA to load because of the compression implied
  // by the autotiler.
}

void activity_kiki_scroll(void) {
  #ifdef __NDS__
  if (!flashing_accepted) {
    helpscreen(helpsect_health_warning, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    if (!(new_keys & (KEY_A | KEY_START))) return;
    flashing_accepted = true;
  }

  bool fast_fps = false;
  #endif
  scrolleffect curr_effect = SCROLLEFFECT_NONE;
  bool start = true;
  int reload = 1;
  bool is_even_frame = false;
  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  load_kiki_bg();
  do {
    reload = read_pad_help_check(helpsect_vertical_scroll_test);
    if(start) {
      reload = 1;
      start = false;
    }
    move_1d_scroll();
    #ifdef __NDS__
    if ((new_keys & KEY_X) || (new_keys & KEY_R))
      fast_fps = !fast_fps;
    if ((new_keys & KEY_Y) || (new_keys & KEY_L)) {
      if(curr_effect == SCROLLEFFECT_BFI)
        curr_effect = SCROLLEFFECT_NONE;
      else
        curr_effect++;
    }
    #endif

    VBlankIntrWait();
    if(reload) {
      scrolltest_y = 0;
      is_even_frame = false;
      BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_64|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
      BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(BFISCROLLTEST);
      BG_OFFSET[0].x = (256 - SCREEN_WIDTH) / 2;
      BG_OFFSET[1].x = BG_OFFSET[1].y = 0;
      dmaCopy(kikipalette0, BG_PALETTE+0, sizeof(kikipalette0));
      dmaCopy(kikipalette1, BG_PALETTE+16, sizeof(kikipalette1));
      BG_PALETTE[241] = 0;
      REG_DISPCNT = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_64|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
      BGCTRL_SUB[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(BFISCROLLTEST);
      BG_OFFSET_SUB[0].x = (256 - SCREEN_WIDTH) / 2;
      BG_OFFSET_SUB[1].x = BG_OFFSET_SUB[1].y = 0;
      dmaCopy(kikipalette0, BG_PALETTE_SUB+0, sizeof(kikipalette0));
      dmaCopy(kikipalette1, BG_PALETTE_SUB+16, sizeof(kikipalette1));
      BG_PALETTE_SUB[241] = 0;
      REG_DISPCNT_SUB = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #endif
    }
    if((curr_effect == SCROLLEFFECT_BFI) && is_even_frame) {
      REG_DISPCNT = MODE_0 | BG1_ON | ACTIVATE_SCREEN_HW;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      REG_DISPCNT_SUB = MODE_0 | BG1_ON | ACTIVATE_SCREEN_HW;
      #endif
    }
    else {
      REG_DISPCNT = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      REG_DISPCNT_SUB = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #endif
    }
    if((!is_even_frame) || (curr_effect != SCROLLEFFECT_HALF)) {
      BG_OFFSET[0].y = scrolltest_y >> 1;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      BG_OFFSET_SUB[0].y = scrolltest_y >> 1;
      #endif
    }
    #ifdef __NDS__
    if(fast_fps)
      __reset_vcount();
    #endif
    is_even_frame = !is_even_frame;
  } while (!(new_keys & KEY_B));
}

// Horizontal scroll (like Sonic the Hedgehog) //////////////////////

void hill_zone_load_bg(void) {
  LZ77UnCompVram(greenhillzone_chrTiles, PATRAM4(0, 0));
  LZ77UnCompVram(greenhillzone_chrMap, MAP[PFSCROLLTEST]);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  LZ77UnCompVram(greenhillzone_chrTiles, PATRAM4_SUB(0, 0));
  LZ77UnCompVram(greenhillzone_chrMap, MAP_SUB[PFSCROLLTEST]);
  #endif
}

#ifdef __NDS__
#define HILL_ZONE_TOP_END_Y 24
#define HILL_ZONE_MIDDLE_END_Y 152
#else
#define HILL_ZONE_TOP_END_Y 24
#define HILL_ZONE_MIDDLE_END_Y 128
#endif

static void __hill_zone_set_scroll(uint16_t *hdmaTable, unsigned int x, bool reload) {
  if(reload) {
    BGCTRL[1] = BG_16_COLOR|BG_WID_64|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
    dmaCopy(greenhillzone_chrPal, BG_PALETTE+0, sizeof(greenhillzone_chrPal));
    BG_PALETTE[241] = 0;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    BGCTRL_SUB[1] = BG_16_COLOR|BG_WID_64|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
    BG_PALETTE_SUB[241] = 0;
    dmaCopy(greenhillzone_chrPal, BG_PALETTE_SUB+0, sizeof(greenhillzone_chrPal));
    #endif
  }

  // Because libgba's ISR takes so long, we're already out of hblank
  // before Halt() returns.
  for (int i = 0; i < HILL_ZONE_TOP_END_Y; ++i)
    hdmaTable[i] = x >> 3;
  for (int i = HILL_ZONE_TOP_END_Y; i < HILL_ZONE_MIDDLE_END_Y; ++i)
    hdmaTable[i] = x >> 2;
  for (int i = HILL_ZONE_MIDDLE_END_Y; i < SCREEN_HEIGHT; ++i)
    hdmaTable[i] = x;
  
  REG_DMA0CNT = 0;
  REG_DMA0SAD = (intptr_t)&(hdmaTable[1]);
  REG_DMA0DAD = (intptr_t)&(BG_OFFSET[1].x);
  REG_DMA0CNT = 1|DMA_DST_RELOAD|DMA_SRC_INC|DMA_REPEAT|DMA16|DMA_HBLANK|DMA_ENABLE;
  BG_OFFSET[1].x = hdmaTable[0];
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  REG_DMA1CNT = 0;
  REG_DMA1SAD = (intptr_t)&(hdmaTable[1]);
  REG_DMA1DAD = (intptr_t)&(BG_OFFSET_SUB[1].x);
  REG_DMA1CNT = 1|DMA_DST_RELOAD|DMA_SRC_INC|DMA_REPEAT|DMA16|DMA_HBLANK|DMA_ENABLE;
  BG_OFFSET_SUB[1].x = hdmaTable[0];
  #endif
}

// Parallax scrolling for hill zone
void hill_zone_set_scroll(uint16_t *hdmaTable, unsigned int x) {
    __hill_zone_set_scroll(hdmaTable, x, true);
}

void activity_hill_zone_scroll(void) {
  #ifdef __NDS__
  if (!flashing_accepted) {
    helpscreen(helpsect_health_warning, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    if (!(new_keys & (KEY_A | KEY_START))) return;
    flashing_accepted = true;
  }

  bool fast_fps = false;
  #endif
  scrolleffect curr_effect = SCROLLEFFECT_NONE;
  bool start = true;
  int reload = 1;
  int selected_scrolltest_y = scrolltest_y;
  bool is_even_frame = false;
  uint16_t *hdmaTable = (uint16_t*)PATRAM4(0,160);

  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  hill_zone_load_bg();
  load_bfi_bg();
  do {
    reload = read_pad_help_check(helpsect_hill_zone_scroll_test);
    if(start) {
      reload = 1;
      start = false;
    }
    move_1d_scroll();
    if(reload)
        selected_scrolltest_y = scrolltest_y = 0;
    #ifdef __NDS__
    if ((new_keys & KEY_X) || (new_keys & KEY_R))
      fast_fps = !fast_fps;
    if ((new_keys & KEY_Y) || (new_keys & KEY_L)) {
      if(curr_effect == SCROLLEFFECT_BFI)
        curr_effect = SCROLLEFFECT_NONE;
      else
        curr_effect++;
    }
    #endif
    

    VBlankIntrWait();
    if((curr_effect == SCROLLEFFECT_BFI) && is_even_frame) {
      BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(BFISCROLLTEST);
      REG_DISPCNT = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(BFISCROLLTEST);
      REG_DISPCNT_SUB = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
      #endif
    }
    else {
      REG_DISPCNT = MODE_0 | BG1_ON | ACTIVATE_SCREEN_HW;
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      REG_DISPCNT_SUB = MODE_0 | BG1_ON | ACTIVATE_SCREEN_HW;
      #endif
    }
    if((!is_even_frame) || ((curr_effect != SCROLLEFFECT_HALF)))
      selected_scrolltest_y = scrolltest_y;

    __hill_zone_set_scroll(hdmaTable, selected_scrolltest_y, reload);
    #ifdef __NDS__
    if(fast_fps)
      __reset_vcount();
    #endif
    is_even_frame = !is_even_frame;
  } while (!(new_keys & KEY_B));
  REG_DMA0CNT = 0;
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  REG_DMA1CNT = 0;
  #endif
}

