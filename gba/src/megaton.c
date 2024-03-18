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
#include <gba_input.h>
#include <gba_sound.h>
#include <gba_video.h>
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
static const char megaton_labels[] =
  "\x83""\x88""off\n"
  "\x84""\x90""on\n"
  "\x38""\x78""Press A when reticles align\n"
  "\x44""\x80""Direction\n"
  "\x83""\x80""\x1D\x1C\n"  // Left/Right
  "\xA3""\x80""\x1E\x1F\n"  // Up/Down
  "\x44""\x88""Randomize\n"
  "\x44""\x90""Audio";

static void megaton_draw_boolean(unsigned int y, unsigned int value) {
  MAP[PFMAP][y][15] = value ? CHECKED_TILE : UNCHECKED_TILE;
  unsigned int onoff = value ? WORD_ON : WORD_OFF;
  MAP[PFMAP][y][16] = onoff;
  MAP[PFMAP][y][17] = onoff + 1;
}

static void megaton_draw_reticle(unsigned int x, unsigned int y) {
  unsigned int i = oam_used;
  y = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_SQUARE;
  x = OBJ_X(x) | ATTR1_SIZE_16;

  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x;
  SOAM[i++].attr2 = RETICLE_TILE;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + 16 + OBJ_HFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  y += 16;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + OBJ_VFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  SOAM[i].attr0 = y;
  SOAM[i].attr1 = x + 16 + OBJ_HFLIP + OBJ_VFLIP;
  SOAM[i++].attr2 = RETICLE_TILE;
  oam_used = i;
}

void activity_megaton() {
  signed char lag[NUM_TRIALS] = {-1};
  unsigned int x = 129, xtarget = 160;
  unsigned int with_audio = 1, dir = 1, randomize = 1;
  unsigned int progress = 0, y = 0;

  load_common_bg_tiles();
  load_common_obj_tiles();
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;   // C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND1CNT_L = 0x08;   // no sweep
  dma_memset16(MAP[PFMAP], BLANK_TILE, 32*20*2);
  vwfDrawLabels(megaton_labels, PFMAP, 0x44);

  // Draw stationary reticle
  for (unsigned int y = 0; y < 2; ++y) {
    for (unsigned int x = 0; x < 2; ++x) {
      unsigned int t = 0x0028 + y * 2 + x;
      MAP[PFMAP][7+y][13+x] = t;
      MAP[PFMAP][7+y][16-x] = t ^ 0x400;
      MAP[PFMAP][10-y][13+x] = t ^ 0x800;
      MAP[PFMAP][10-y][16-x] = t ^ 0xC00;
    }
  }
  
  // Make space for results
  dma_memset16(PATRAM4(0, 0x30), 0x0000, 32 * 20);
  loadMapRowMajor(&(MAP[PFMAP][2][2]), 0x30, 2, 10);

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
      uint32_t *tileaddr = PATRAM4(0, 0x30 + progress * 2);
      dma_memset16(tileaddr, 0x0000, 32 * 2);
      if (early) {
        vwf8PutTile(tileaddr, 'E', 0, 1);
      }
      unsigned int tens = value / 10;
      if (tens) {
        vwf8PutTile(tileaddr, tens + '0', 6, 1);
      }
      vwf8PutTile(tileaddr, (value - tens * 10) + '0', 11, 1);
      if (!early && value <= 25) lag[progress++] = value;
    }
    REG_SOUND2CNT_L = ((new_keys & KEY_A) && with_audio) ? 0xA080 : 0x0000;
    REG_SOUND2CNT_H = (2048 - 262) | 0x8000;
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
      megaton_draw_reticle(104 + x - 128, 56);
    }
    if (dir & 0x02) {
      megaton_draw_reticle(104, 56 + x - 128);
    }
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    BG_COLORS[0] = (x == 128 && with_audio) ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    BG_COLORS[1] = OBJ_COLORS[1] = RGB5(31, 31, 31);
    BG_COLORS[2] = RGB5(20, 25, 31);
    ppu_copy_oam();

    // Draw the cursor
    for (unsigned int i = 0; i < 3; ++i) {
      unsigned int tilenum = (i == y) ? ARROW_TILE : BLANK_TILE;
      MAP[PFMAP][i + 16][7] = tilenum;
    }
    MAP[PFMAP][16][15] = (dir & 0x01) ? CHECKED_TILE : UNCHECKED_TILE;
    MAP[PFMAP][16][19] = (dir & 0x02) ? CHECKED_TILE : UNCHECKED_TILE;
    megaton_draw_boolean(17, randomize);
    megaton_draw_boolean(18, with_audio);

    // beep
    REG_SOUND1CNT_H = (x == 128 && with_audio) ? 0xA080 : 0x0000;
    REG_SOUND1CNT_X = (2048 - 131) | 0x8000;
  } while (!(new_keys & KEY_B) && (progress < NUM_TRIALS));

  BG_COLORS[0] = RGB5(0, 0, 0);
  REG_SOUNDCNT_X = 0;  // reset audio
  if (progress < 10) return;

  // Display average: First throw away all labels below Y=120
  dma_memset16(MAP[PFMAP][15], BLANK_TILE, 32*4*2);

  unsigned int sum = 0;
  for (unsigned int i = 0; i < NUM_TRIALS; ++i) {
    sum += lag[i];
  }
  unsigned int whole_frames = sum / NUM_TRIALS;
  posprintf(help_line_buffer, "\x40\x80""Average lag: %d.%d frames",
            whole_frames, sum - whole_frames * NUM_TRIALS);
  vwfDrawLabels(help_line_buffer, PFMAP, 0x44);

  // Ignore spurious presses
  for (unsigned int i = 20; i > 0; --i) {
    VBlankIntrWait();
  }
  
  do {
    VBlankIntrWait();
    read_pad();
  } while (!new_keys);

  // TODO: Display average lag
}
