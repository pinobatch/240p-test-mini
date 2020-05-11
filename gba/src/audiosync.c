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
#include <gba_video.h>
#include <gba_sound.h>
#include <gba_input.h>

extern const unsigned char helpsect_audio_sync[];
#define PFMAP 23

static const BarsListEntry audiosync_rects[] = {
  {  0,128,240,136, 1},
  {  0, 24, 24, 40, 2},
  { 24, 24, 48, 40, 3},
  { 48, 24, 72, 40, 4},
  { 72, 24, 96, 40, 5},
  {144, 24,168, 40, 5},
  {168, 24,192, 40, 4},
  {192, 24,216, 40, 3},
  {216, 24,240, 40, 2},
  {0xFF}
};

static const unsigned char min_progress[6] = {
  120, 0, 40, 60, 80, 100
};

void activity_audio_sync() {
  unsigned int progress = 0, running = 0;

  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;   // C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND1CNT_L = 0x08;   // no sweep

  draw_barslist(audiosync_rects);
  load_common_obj_tiles();

  do {
    if (progress < 120) {
      REG_SOUND1CNT_H = 0;  // note cut
      REG_SOUND1CNT_X = 0x8000;
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

    unsigned int y = (progress < 60) ? 128 - progress : 8 + progress;
    SOAM[0].attr0 = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_SQUARE;
    SOAM[0].attr1 = 119 | ATTR1_SIZE_8;
    SOAM[0].attr2 = 0x0023;
    ppu_clear_oam(1);

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    for (unsigned int i = 0; i < 6; ++i) {
      BG_COLORS[i] = progress >= min_progress[i] ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    }
    OBJ_COLORS[1] = RGB5(31, 31, 31);
    ppu_copy_oam();

    if (progress == 120) {
      REG_SOUND1CNT_H = 0xA080;  // 2/3 volume, 50% duty
      REG_SOUND1CNT_X = (2048 - 131) + 0x8000;  // pitch
    }
  } while (!(new_keys & KEY_B));
  REG_SOUNDCNT_X = 0;  // reset audio
}
