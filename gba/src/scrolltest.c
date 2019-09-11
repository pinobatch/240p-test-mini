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
#include <gba_input.h>
#include <gba_video.h>
#include <gba_dma.h>
#include <gba_compression.h>
#include <gba_interrupt.h>

extern const unsigned char helpsect_grid_scroll_test[];
extern const unsigned char helpsect_hill_zone_scroll_test[];
extern const unsigned char helpsect_vertical_scroll_test[];

#define PFSCROLLTEST 22

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
    BG_COLORS[0] = inverted ? RGB5(31,31,31) : RGB5(0, 0, 0);
    BG_COLORS[1] = inverted ? RGB5(0, 0, 0) : RGB5(31,31,31);
    REG_DISPCNT = MODE_0 | BG0_ON;
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

extern const unsigned int kikimap_chrTiles[32];
extern const VBTILE kikitiles_chrTiles[24];
static const unsigned short kikipalette0[] = {
  RGB5( 0, 0, 0),RGB5(15,11, 7),RGB5(23,18,13),RGB5(31,25,19)
};
static const unsigned short kikipalette1[] = {
  RGB5( 0, 0, 0),RGB5(18,18,18),RGB5(0, 25, 0),RGB5(25,25,25)
};

static void load_kiki_bg(void) {
  bitunpack2(PATRAM4(0, 0), kikitiles_chrTiles, sizeof(kikitiles_chrTiles));
  dma_memset16(MAP[PFSCROLLTEST], 0x0000, 32*64*2);

  dma_memset16(help_line_buffer, 0x0000, 16);  // Clear metatile buffer
  for (unsigned int y = 0; y < 32; ++y) {
    // Decode one row
    unsigned int tiletotopleft = 0;
    unsigned int tiletoleft = 0;

    // Run Markov chain: guess the most common tile below each
    for (unsigned int x = 0; x < 16; x++) {
      unsigned int tilethere = help_line_buffer[x];
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
      help_line_buffer[x] = tiletoleft;
    }
    
    // Replace with path from replaceloop
    unsigned int wallbits = kikimap_chrTiles[y];
    for (unsigned int x = 0; x < 16 && wallbits; ++x) {
      unsigned int replacement = wallbits & 0x03;
      if (replacement) help_line_buffer[x] = replacement;
      wallbits >>= 2;
    }

    // Render metatile row
    for (unsigned int x = 0; x < 16; ++x) {
      unsigned int mtid = help_line_buffer[x];
      unsigned int attr = (mtid >= 1 && mtid <= 3) ? 0x1000 : 0x0000;
      MAP[PFSCROLLTEST][y * 2    ][x * 2    ] = metatiles[mtid][0] | attr;
      MAP[PFSCROLLTEST][y * 2    ][x * 2 + 1] = metatiles[mtid][1] | attr;
      MAP[PFSCROLLTEST][y * 2 + 1][x * 2    ] = metatiles[mtid][2] | attr;
      MAP[PFSCROLLTEST][y * 2 + 1][x * 2 + 1] = metatiles[mtid][3] | attr;
    }
  }
  // This map is a PITA to load because of the compression implied
  // by the autotiler.
}

void activity_kiki_scroll(void) {
  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  load_kiki_bg();
  do {
    read_pad_help_check(helpsect_hill_zone_scroll_test);
    move_1d_scroll();

    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_64|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
    BG_OFFSET[0].y = scrolltest_y >> 1;
    BG_OFFSET[0].x = 8;
    REG_DISPCNT = MODE_0 | BG0_ON;
    dmaCopy(kikipalette0, BG_COLORS+0, sizeof(kikipalette0));
    dmaCopy(kikipalette1, BG_COLORS+16, sizeof(kikipalette1));
  } while (!(new_keys & KEY_B));
}

// Horizontal scroll (like Sonic the Hedgehog) //////////////////////

extern const unsigned short greenhillzone_chrPal[8];
extern const unsigned short greenhillzone_chrMap[];  // LZ77
extern const unsigned short greenhillzone_chrTiles[];  // LZ77

void hill_zone_load_bg(void) {
  LZ77UnCompVram(greenhillzone_chrTiles, PATRAM4(0, 0));
  LZ77UnCompVram(greenhillzone_chrMap, MAP[PFSCROLLTEST]);
}

// Parallax scrolling for hill zone
void hill_zone_set_scroll(unsigned int x) {
  BGCTRL[1] = BG_16_COLOR|BG_WID_64|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
  dmaCopy(greenhillzone_chrPal, BG_COLORS+0, sizeof(greenhillzone_chrPal));
  irqEnable(IRQ_VCOUNT);
  BG_OFFSET[1].x = x >> 3;

  // Wait for y=24 and change the scroll
  REG_DISPSTAT = (REG_DISPSTAT & 0xFF) | (24 << 8);
  Halt();
  BG_OFFSET[1].x = x >> 2;

  // TODO: Wait for y=128
  REG_DISPSTAT = (REG_DISPSTAT & 0xFF) | (128 << 8);
  Halt();
  BG_OFFSET[1].x = x;

  BG_OFFSET[1].y = 0;
  irqDisable(IRQ_VCOUNT);
}

void activity_hill_zone_scroll(void) {
  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  hill_zone_load_bg();
  do {
    read_pad_help_check(helpsect_hill_zone_scroll_test);
    move_1d_scroll();

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG1_ON;
    hill_zone_set_scroll(scrolltest_y);
  } while (!(new_keys & KEY_B));
}

