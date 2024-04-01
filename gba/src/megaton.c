/*
Manual lag test for 160p Test Suite
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
#include "posprintf.h"

#define PFMAP 23
#define NUM_TRIALS 10
#define BLANK_TILE 0x0004
#define ARROW_TILE 0x0005
#define CHECKED_TILE 0x0027
#define UNCHECKED_TILE 0x0026
#define RETICLE_TILE 0x0028
#define WORD_OFF 0x0044
#define WORD_ON 0x0046

// The "On" and "Off" labels must come first because they cause
// text to be allocated with off and on at WORD_OFF and WORD_ON

static const char megaton_positions[] = {
    (SCREEN_WIDTH/2) + 11, SCREEN_HEIGHT - 24,
    (SCREEN_WIDTH/2) + 12, SCREEN_HEIGHT - 16,
    (SCREEN_WIDTH/2) - 64, SCREEN_HEIGHT - 40,
    (SCREEN_WIDTH/2) - 52, SCREEN_HEIGHT - 32,
    (SCREEN_WIDTH/2) + 11, SCREEN_HEIGHT - 32,
    (SCREEN_WIDTH/2) + 43, SCREEN_HEIGHT - 32,
    (SCREEN_WIDTH/2) - 52, SCREEN_HEIGHT - 24,
    (SCREEN_WIDTH/2) - 52, SCREEN_HEIGHT - 16
};

static const char avg_lag_positions[] = {
    (SCREEN_WIDTH/2) - 56, SCREEN_HEIGHT - 32
};

static const char megaton_labels[] =
  "off\n"
  "on\n"
  "Press A when reticles align\n"
  "Direction\n"
  "\x1D\x1C\n"  // Left/Right
  "\x1E\x1F\n"  // Up/Down
  "Randomize\n"
  "Audio";

static void megaton_draw_boolean(SCREENMAT *map_address, unsigned int y, unsigned int value) {
  map_address[PFMAP][y][SCREEN_WIDTH >> 4] = value ? CHECKED_TILE : UNCHECKED_TILE;
  unsigned int onoff = value ? WORD_ON : WORD_OFF;
  map_address[PFMAP][y][(SCREEN_WIDTH >> 4) + 1] = onoff;
  map_address[PFMAP][y][(SCREEN_WIDTH >> 4) + 2] = onoff + 1;
}

static void megaton_draw_reticle(unsigned int x, unsigned int y) {
  unsigned int i = oam_used;
  y = ATTR0_Y(y) | ATTR0_4BPP | ATTR0_SQUARE;
  x = ATTR1_X(x) | ATTR1_SIZE_16;

  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x;
  SOAM[i++].attr2 = RETICLE_TILE;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + 16 + ATTR1_HFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  y += 16;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + ATTR1_VFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + 16 + ATTR1_HFLIP + ATTR1_VFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  oam_used = i;
}

static void megaton_draw_variable_data(SCREENMAT *map_address, unsigned int y, unsigned int dir, unsigned int randomize, unsigned int with_audio) {
    // Draw the cursor
    for (unsigned int i = 0; i < 3; ++i) {
      unsigned int tilenum = (i == y) ? ARROW_TILE : BLANK_TILE;
      map_address[PFMAP][i + (SCREEN_HEIGHT >> 3) - 4][(SCREEN_WIDTH >> 4) - 8] = tilenum;
    }
    map_address[PFMAP][(SCREEN_HEIGHT >> 3) - 4][SCREEN_WIDTH >> 4] = (dir & 0x01) ? CHECKED_TILE : UNCHECKED_TILE;
    map_address[PFMAP][(SCREEN_HEIGHT >> 3) - 4][(SCREEN_WIDTH >> 4) + 4] = (dir & 0x02) ? CHECKED_TILE : UNCHECKED_TILE;
    megaton_draw_boolean(map_address, (SCREEN_HEIGHT >> 3) - 3, randomize);
    megaton_draw_boolean(map_address, (SCREEN_HEIGHT >> 3) - 2, with_audio);
}

static void megaton_draw_static_reticle(SCREENMAT *map_address) {
  // Draw stationary reticle
  for (unsigned int y = 0; y < 2; ++y) {
    for (unsigned int x = 0; x < 2; ++x) {
      unsigned int t = 0x0028 + y * 2 + x;
      map_address[PFMAP][7+y][(SCREEN_WIDTH>>4)-2+x] = t;
      map_address[PFMAP][7+y][(SCREEN_WIDTH>>4)+1-x] = t ^ 0x400;
      map_address[PFMAP][10-y][(SCREEN_WIDTH>>4)-2+x] = t ^ 0x800;
      map_address[PFMAP][10-y][(SCREEN_WIDTH>>4)+1-x] = t ^ 0xC00;
    }
  }
}

static void megaton_print_values(uint32_t *tileaddr, unsigned int value, unsigned int early) {
  dma_memset16(tileaddr, 0x0000, 32 * 2);
  if (early) {
    vwf8PutTile(tileaddr, 'E', 0, 1);
  }
  unsigned int tens = value / 10;
  if (tens) {
    vwf8PutTile(tileaddr, tens + '0', 6, 1);
  }
  vwf8PutTile(tileaddr, (value - tens * 10) + '0', 11, 1);
}

void activity_megaton() {
  signed char lag[NUM_TRIALS] = {-1};
  unsigned int x = 129, xtarget = 160;
  unsigned int with_audio = 1, dir = 1, randomize = 1;
  unsigned int progress = 0, y = 0;

  load_common_bg_tiles();
  load_common_obj_tiles();
  #ifdef __NDS__
  soundEnable();
  #else
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;   // C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND1CNT_L = 0x08;   // no sweep
  #endif

  dma_memset16(se_mat[PFMAP], BLANK_TILE, 32*(SCREEN_HEIGHT>>3)*2);

  megaton_draw_static_reticle(se_mat);
  // Make space for results
  dma_memset16(tile_mem[0][0x30].data, 0x0000, 32 * 2 * NUM_TRIALS);
  loadMapRowMajor(&(se_mat[PFMAP][2][2]), 0x30, 2, NUM_TRIALS);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(se_mat_sub[PFMAP], BLANK_TILE, 32*(SCREEN_HEIGHT>>3)*2);

  megaton_draw_static_reticle(se_mat_sub);
  // Make space for results
  dma_memset16(tile_mem_sub[0][0x30].data, 0x0000, 32 * 2 * NUM_TRIALS);
  loadMapRowMajor(&(se_mat_sub[PFMAP][2][2]), 0x30, 2, NUM_TRIALS);
  #endif
  vwfDrawLabelsPositionBased(megaton_labels, megaton_positions, PFMAP, 0x44);

  do {
    read_pad_help_check(helpsect_timing_and_reflex_test);
    
    if (new_keys & KEY_B) {
      break;
    }
    if (new_keys & KEY_A) {
      signed int diff = x - 128;
      if (xtarget < 128) diff = -diff;
      unsigned int early = diff < 0;
      unsigned int value = early ? -diff : diff;
      megaton_print_values(tile_mem[0][0x30 + progress * 2].data, value, early);
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      megaton_print_values(tile_mem_sub[0][0x30 + progress * 2].data, value, early);
      #endif
      if (!early && value <= 25) lag[progress++] = value;
    }
    #ifdef __NDS__
    if((new_keys & KEY_A) && with_audio)
      startPlayingSound(PRESS_A_SOUND_ID);
    else
      killPlayingSound(PRESS_A_SOUND_ID);
    #else
    REG_SOUND2CNT_L = ((new_keys & KEY_A) && with_audio) ? 0xA080 : 0x0000;
    REG_SOUND2CNT_H = (2048 - 262) | 0x8000;
    #endif
    if ((new_keys & KEY_UP) && y > 0) {
      --y;
    }
    if ((new_keys & KEY_DOWN) && y < 2) {
      ++y;
    }
    if (new_keys & (KEY_LEFT | KEY_RIGHT)) {
      switch (y) {
        case 0:  // change direction
        dir += (new_keys & KEY_LEFT) ? 2 : 1;
        if (dir > 3) dir -= 3;
        break;
        case 1:
        randomize = !randomize;
        break;
        case 2:
        with_audio = !with_audio;
        break;
      }
    }
    
    // Move reticle
    x += (xtarget > x) ? 1 : -1;
    if (x == xtarget) {
      xtarget = 36 + 128;
      if (randomize) xtarget += (lcg_rand() >> 12) - 8;
      if (x > 128) xtarget = 256 - xtarget;
    }

    oam_used = 0;
    if (dir & 0x01) {
      megaton_draw_reticle((SCREEN_WIDTH / 2) - 16 + x - 128, 56);
    }
    if (dir & 0x02) {
      megaton_draw_reticle((SCREEN_WIDTH / 2) - 16, 56 + x - 128);
    }
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    pal_bg_mem[0] = (x == 128 && with_audio) ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    pal_bg_mem[1] = pal_obj_mem[1] = RGB5(31, 31, 31);
    pal_bg_mem[2] = RGB5(20, 25, 31);
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_BGCNT_SUB[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS_SUB[0].x = REG_BG_OFS_SUB[0].y = 0;
    pal_bg_mem_sub[0] = (x == 128 && with_audio) ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    pal_bg_mem_sub[1] = pal_obj_mem_sub[1] = RGB5(31, 31, 31);
    pal_bg_mem_sub[2] = RGB5(20, 25, 31);
    #endif
    ppu_copy_oam();

    megaton_draw_variable_data(se_mat, y, dir, randomize, with_audio);
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    megaton_draw_variable_data(se_mat_sub, y, dir, randomize, with_audio);
    #endif

    // beep
    #ifdef __NDS__
    if(x == 128 && with_audio)
      startPlayingSound(TICK_SOUND_ID);
    else
      killPlayingSound(TICK_SOUND_ID);
    #else
    REG_SOUND1CNT_H = (x == 128 && with_audio) ? 0xA080 : 0x0000;
    REG_SOUND1CNT_X = (2048 - 131) | 0x8000;
    #endif
  } while (!(new_keys & KEY_B) && (progress < NUM_TRIALS));

  pal_bg_mem[0] = RGB5(0, 0, 0);
  #ifdef __NDS__
  killPlayingSound(TICK_SOUND_ID);
  killPlayingSound(PRESS_A_SOUND_ID);
  soundDisable();
  #else
  REG_SOUNDCNT_X = 0;  // reset audio
  #endif
  if (progress < 10) return;

  // Display average: First throw away all labels below Y=120
  dma_memset16(se_mat[PFMAP][(SCREEN_HEIGHT - 40)>> 3], BLANK_TILE, 32*4*2);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(se_mat_sub[PFMAP][(SCREEN_HEIGHT - 40)>> 3], BLANK_TILE, 32*4*2);
  #endif

  unsigned int sum = 0;
  for (unsigned int i = 0; i < NUM_TRIALS; ++i) {
    sum += lag[i];
  }
  unsigned int whole_frames = sum / NUM_TRIALS;
  posprintf(help_line_buffer, "Average lag: %d.%d frames",
            whole_frames, sum - whole_frames * NUM_TRIALS);
  vwfDrawLabelsPositionBased(help_line_buffer, avg_lag_positions, PFMAP, 0x44);

  // Ignore spurious presses
  for (unsigned int i = 20; i > 0; --i) {
    VBlankIntrWait();
  }
  
  do {
    VBlankIntrWait();
    read_pad();
  } while (!new_keys);
}
