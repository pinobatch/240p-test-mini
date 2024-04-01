/*
Audio sync test for 160p Test Suite
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

static const BarsListEntry audiosync_rects[] = {
  { 0,GET_SLICE_X(SCREEN_HEIGHT, 4, 3)+8,SCREEN_WIDTH,GET_SLICE_X(SCREEN_HEIGHT, 4, 3)+16, 1},
  { 0,GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 1),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 2},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 1),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 3),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 4},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 3),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 4),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 6),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 7),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 7),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 8),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 4},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 8),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,GET_SLICE_X(SCREEN_WIDTH, 10, 9),GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 10, 9),GET_SLICE_X(SCREEN_HEIGHT, 4, 1)-16,SCREEN_WIDTH,GET_SLICE_X(SCREEN_HEIGHT, 4, 1), 2},
  {0xFF}
};

static const unsigned char min_progress[6] = {
  120, 0, 40, 60, 80, 100
};

void activity_audio_sync() {
  unsigned int progress = 0, running = 0;

  #ifdef __NDS__
  soundEnable();
  #else
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;   // C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND1CNT_L = 0x08;   // no sweep
  #endif

  draw_barslist(audiosync_rects);
  load_common_obj_tiles();

  do {
    if (progress < 120) {
      #ifdef __NDS__
      killPlayingSound(TICK_SOUND_ID);
      #else
      REG_SOUND1CNT_H = 0;  // note cut
      REG_SOUND1CNT_X = 0x8000;
      #endif
      read_pad_help_check(helpsect_audio_sync);
    
      if (new_keys & KEY_A) {
        running = !running;
        if (running) progress = 0;
      }
    }
    if (running) {
      progress += 1;
      if (progress >= 122) progress = 0;
    }

    unsigned int y = (progress < 60) ? GET_SLICE_X(SCREEN_HEIGHT, 4, 3) + 8 - progress : GET_SLICE_X(SCREEN_HEIGHT, 4, 3) + 8 - 120 + progress;
    SOAM[0].attr0 = ATTR0_Y(y) | ATTR0_4BPP | ATTR0_SQUARE;
    SOAM[0].attr1 = ((SCREEN_WIDTH - 1) / 2) | ATTR1_SIZE_8;
    SOAM[0].attr2 = 0x0023;
    ppu_clear_oam(1);

    VBlankIntrWait();
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    for (unsigned int i = 0; i < 6; ++i) {
      pal_bg_mem[i] = progress >= min_progress[i] ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    }
    pal_obj_mem[1] = RGB5(31, 31, 31);
    ppu_copy_oam();

    if (progress == 120) {
      #ifdef __NDS__
      startPlayingSound(TICK_SOUND_ID);
      #else
      REG_SOUND1CNT_H = 0xA080;  // 2/3 volume, 50% duty
      REG_SOUND1CNT_X = (2048 - 131) + 0x8000;  // pitch
      #endif
    }
  } while (!(new_keys & KEY_B));
  #ifdef __NDS__
  killPlayingSound(TICK_SOUND_ID);
  soundDisable();
  #else
  REG_SOUNDCNT_X = 0;  // reset audio
  #endif
}
