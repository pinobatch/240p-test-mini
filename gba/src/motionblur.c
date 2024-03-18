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

#define PFMAP 23
#define NUM_PARAMS 6
#define BLANK_TILE 0x0004
#define ARROW_TILE 0x0005

#define MOTION_BLUR_START_Y 2
#define MOTION_BLUR_END_Y ((SCREEN_HEIGHT >> 3) - 8)

// back shade, on time, on shade, off time, off shade, stripes
static const unsigned char param_max[NUM_PARAMS] = {
  31, 60, 31, 60, 31, 1
};
static const unsigned char param_min[NUM_PARAMS] = {
  0, 1, 0, 1, 0, 0
};

static const char motion_blur_positions[] = {
    ((SCREEN_WIDTH >> 4)-4)*8, (MOTION_BLUR_END_Y+4)*8,
    ((SCREEN_WIDTH >> 4)-4)*8, (MOTION_BLUR_END_Y+2)*8,
    ((SCREEN_WIDTH >> 4)-4)*8, (MOTION_BLUR_END_Y+1)*8,
    (((SCREEN_WIDTH >> 4)-2)*8)+2, (MOTION_BLUR_END_Y+2)*8,
    (((SCREEN_WIDTH >> 4)-2)*8)+2, (MOTION_BLUR_END_Y+3)*8,
    (((SCREEN_WIDTH >> 4)-2)*8)+2, (MOTION_BLUR_END_Y+4)*8,
    (((SCREEN_WIDTH >> 4)-2)*8)+2, (MOTION_BLUR_END_Y+5)*8,
    ((SCREEN_WIDTH >> 4)-4)*8, (MOTION_BLUR_END_Y+6)*8
};

// First two need to be Off and On to set up later
static const char motion_blur_labels[] = 
  "Off\n"
  "On\n"
  "Back shade\n"
  "time\n"
  "shade\n"
  "time\n"
  "shade\n"
  "Stripes";

static void draw_motion_blur_values(NAMETABLE *map_address, unsigned int y, unsigned char params[NUM_PARAMS]) {
    for (unsigned int i = 0; i < 6; ++i) {
      map_address[PFMAP][MOTION_BLUR_END_Y + 1 + i][(SCREEN_WIDTH >> 4) - 5] = (i == y) ? ARROW_TILE : BLANK_TILE;
    }
    for (unsigned int i = 0; i < 5; ++i) {
      unsigned int value = params[i];
      unsigned int tens = value / 10;
      map_address[PFMAP][MOTION_BLUR_END_Y + 1 + i][(SCREEN_WIDTH >> 4) + 4] = 0x0010 + (value - tens * 10);
      map_address[PFMAP][MOTION_BLUR_END_Y + 1 + i][(SCREEN_WIDTH >> 4) + 3] = tens ? 0x0010 + tens : BLANK_TILE;
    }
    
    unsigned int stripes_tile = params[5] ? 0x22 : 0x20;  // On and Off
    map_address[PFMAP][MOTION_BLUR_END_Y + 6][(SCREEN_WIDTH >> 4) + 3] = stripes_tile;
    map_address[PFMAP][MOTION_BLUR_END_Y + 6][(SCREEN_WIDTH >> 4) + 4] = stripes_tile + 1;
}

// Health and safety
bool flashing_accepted = false;
  
void activity_motion_blur() {
  unsigned char params[NUM_PARAMS] = {15, 1, 31, 1, 0, 0};
  unsigned int phase = 0, timeleft = 0, running = 0;

  if (!flashing_accepted) {
    helpscreen(helpsect_health_warning, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    if (!(new_keys & (KEY_A | KEY_START))) return;
    flashing_accepted = true;
  }
  #ifdef __NDS__
  bool fast_fps = false;
  #endif

  load_common_bg_tiles();
  dma_memset16(MAP[PFMAP], BLANK_TILE, 32*(SCREEN_HEIGHT >> 3)*2);
  for (unsigned int y = MOTION_BLUR_START_Y; y < MOTION_BLUR_END_Y; ++y)
    dma_memset16(MAP[PFMAP][y] + (SCREEN_WIDTH >> 4) - ((MOTION_BLUR_END_Y-MOTION_BLUR_START_Y)/2), 0x0A, (MOTION_BLUR_END_Y-MOTION_BLUR_START_Y)*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(MAP_SUB[PFMAP], BLANK_TILE, 32*(SCREEN_HEIGHT >> 3)*2);
  for (unsigned int y = MOTION_BLUR_START_Y; y < MOTION_BLUR_END_Y; ++y)
    dma_memset16(MAP_SUB[PFMAP][y] + (SCREEN_WIDTH >> 4) - ((MOTION_BLUR_END_Y-MOTION_BLUR_START_Y)/2), 0x0A, (MOTION_BLUR_END_Y-MOTION_BLUR_START_Y)*2);
  #endif
  vwfDrawLabelsPositionBased(motion_blur_labels, motion_blur_positions, PFMAP, 0x20);
  
  unsigned int y = 0;
  do {
    read_pad_help_check(helpsect_motion_blur);
    autorepeat(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN);
    
    if (new_keys & KEY_A) {
      phase = 0;
      timeleft = 1;
      running = !running;
    }
    #ifdef __NDS__
    if ((new_keys & KEY_X) || (new_keys & KEY_R))
      fast_fps = !fast_fps;
    #endif

    if (running) {
      timeleft -= 1;
      if (timeleft == 0) {
        phase = !phase;
        timeleft = params[phase ? 1 : 3];
      }
    } else {
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
      BG_PALETTE[i] = RGB5(1, 1, 1) * bgc1[i];
    }
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET_SUB[0].x = BG_OFFSET_SUB[0].y = 0;
    for (unsigned int i = 0; i < 4; ++i) {
      BG_PALETTE_SUB[i] = RGB5(1, 1, 1) * bgc1[i];
    }
    #endif

    draw_motion_blur_values(MAP, y, params);
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    draw_motion_blur_values(MAP_SUB, y, params);
    #endif
    REG_DISPCNT = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = MODE_0 | BG0_ON | ACTIVATE_SCREEN_HW;
    #endif
    #ifdef __NDS__
    if(fast_fps)
      __reset_vcount();
    #endif
  } while (!(new_keys & KEY_B));
}
