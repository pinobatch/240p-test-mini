/*
Motion blur test (replaces IRE) for 160p Test Suite
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

extern const unsigned char helpsect_health_warning[];
#define DOC_HEALTH_WARNING ((unsigned int)helpsect_health_warning)

extern const unsigned char helpsect_motion_blur[];
#define PFMAP 23
#define NUM_PARAMS 6
#define BLANK_TILE 0x0004
#define ARROW_TILE 0x0005

// back shade, on time, on shade, off time, off shade, stripes
static const unsigned char param_max[NUM_PARAMS] = {
  31, 20, 31, 20, 31, 1
};
static const unsigned char param_min[NUM_PARAMS] = {
  0, 1, 0, 1, 0, 0
};

// First two need to be Off and On to set up later
static const char motion_blur_labels[] = 
  "\x58""\x80""Off\n"
  "\x58""\x70""On\n"
  "\x58""\x68""Back shade\n"
  "\x6a""\x70""time\n"
  "\x6a""\x78""shade\n"
  "\x6a""\x80""time\n"
  "\x6a""\x88""shade\n"
  "\x58""\x90""Stripes";

// Health and safety
static unsigned char flashing_accepted = 0;
  
void activity_motion_blur() {
  unsigned char params[NUM_PARAMS] = {15, 1, 31, 1, 0, 0};
  unsigned int phase = 0, timeleft = 0, running = 0;

  if (!flashing_accepted) {
    helpscreen(DOC_HEALTH_WARNING, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    if (!(new_keys & (KEY_A | KEY_START))) return;
    flashing_accepted = 1;
  }

  load_common_bg_tiles();
  dma_memset16(MAP[PFMAP], BLANK_TILE, 32*20*2);
  for (unsigned int y = 2; y < 12; ++y) {
    dma_memset16(MAP[PFMAP][y] + 9, 0x0A, 12*2);
  }
  vwfDrawLabels(motion_blur_labels, PFMAP, 0x20);
  
  unsigned int y = 0;
  do {
    read_pad_help_check(helpsect_motion_blur);
    autorepeat(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN);
    
    if (new_keys & KEY_A) {
      phase = 0;
      timeleft = 1;
      running = !running;
    }
    if ((new_keys & KEY_UP) && y > 0) {
      y -= 1;
    }
    if ((new_keys & KEY_DOWN) && y < NUM_PARAMS - 1) {
      y += 1;
    }
    if ((new_keys & KEY_LEFT) && params[y] > param_min[y]) {
      params[y] -= 1;
    }
    if ((new_keys & KEY_RIGHT) && params[y] < param_max[y]) {
      params[y] += 1;
    }

    if (running) {
      timeleft -= 1;
      if (timeleft == 0) {
        phase = !phase;
        timeleft = params[phase ? 1 : 3];
      }
    }

    // Calculate actual colors for this frame
    unsigned char bgc1[4] = {
      params[0], params[0], params[phase ? 2 : 4], params[phase ? 4 : 2]
    };
    if (!params[5]) bgc1[3] = bgc1[2];  // destripe if stripes not on
    if (!running) bgc1[1] = bgc1[1] >= 16 ? 0 : 31;

    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    for (unsigned int i = 0; i < 4; ++i) {
      BG_COLORS[i] = RGB5(1, 1, 1) * bgc1[i];
    }
    for (unsigned int i = 0; i < 6; ++i) {
      MAP[PFMAP][13 + i][10] = (i == y) ? ARROW_TILE : BLANK_TILE;
    }
    for (unsigned int i = 0; i < 5; ++i) {
      unsigned int value = params[i];
      unsigned int tens = value / 10;
      MAP[PFMAP][13 + i][19] = 0x0010 + (value - tens * 10);
      MAP[PFMAP][13 + i][18] = tens ? 0x0010 + tens : BLANK_TILE;
    }
    
    unsigned int stripes_tile = params[5] ? 0x22 : 0x20;  // On and Off
    MAP[PFMAP][18][18] = stripes_tile;
    MAP[PFMAP][18][19] = stripes_tile + 1;
    REG_DISPCNT = MODE_0 | BG0_ON;
  } while (!(new_keys & KEY_B));
}
