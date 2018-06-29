/*
Stopwatch lag test for 160p Test Suite
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
#include <gba_dma.h>

extern const VBTILE stopwatchhand_chrTiles[48];
extern const ONEBTILE stopwatchface_chrTiles[64];
extern const VBTILE stopwatchdigits_chrTiles[64];
extern const unsigned short stopwatchface_chrMap[];

extern const unsigned char helpsect_stopwatch[];
#define PFMAP 23
#define NUM_DIGITS 8
#define NUM_FACE_PHASES 10

static const unsigned char sw_digitmax[NUM_DIGITS] = {
  NUM_FACE_PHASES, 6, 10, 6, 10, 6, 10, 10
};

static const unsigned char sw_digitx[NUM_DIGITS] = {
  23, 21, 18, 16, 13, 11, 8, 6
};

static const unsigned char sw_face_x[NUM_FACE_PHASES] = {
  76, 98, 112, 112, 98, 76, 54, 40, 40, 54
};

static const unsigned char sw_face_y[NUM_FACE_PHASES] = {
  58, 65, 84, 108, 127, 134, 127, 108, 84, 65
};

static const unsigned short bluepalette[3] = {
  RGB5(23,23,31),RGB5(15,15,31),RGB5( 0, 0,31)
};
static const unsigned short redpalette[3] = {
  RGB5(31,23,23),RGB5(31,15,15),RGB5(31, 0, 0)
};

static const char sw_labels[] =
  "\x30\x08""hour\n"
  "\x58\x08""minute\n"
  "\x80\x08""second\n"
  "\xA8\x08""frame";

static void draw_stopwatch_hand(unsigned int phase) {
  unsigned int i = oam_used;
  unsigned int a0 = OBJ_Y(sw_face_y[phase] - 12) | OBJ_16_COLOR | ATTR0_SQUARE;
  unsigned int a1 = OBJ_X(sw_face_x[phase] + 28) | ATTR1_SIZE_16;

  // draw digit
  SOAM[i].attr0 = a0 + 8;
  SOAM[i].attr1 = a1 + 8;
  SOAM[i++].attr2 = phase * 4;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1 + 16 + OBJ_HFLIP;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0 + 16;
  SOAM[i].attr1 = a1 + OBJ_VFLIP;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0 + 16;
  SOAM[i].attr1 = a1 + 16 + OBJ_HFLIP + OBJ_VFLIP;
  SOAM[i++].attr2 = 40;

  // draw hand
  a0 = OBJ_Y(sw_face_y[phase] / 2 + 48) | OBJ_16_COLOR | ATTR0_SQUARE;
  a1 = OBJ_X(sw_face_x[phase] / 2 + 78) | ATTR1_SIZE_8;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1;
  SOAM[i++].attr2 = 44;

  oam_used = i;
}

void activity_stopwatch() {
  unsigned char digits[NUM_DIGITS] = {0};
  unsigned int running = 0, is_lap = 0, hide_face = 0, show_ruler = 0, face_phase = 0;

  dma_memset16(MAP[PFMAP], 0x0000, 32*20*2);
  bitunpack1(PATRAM4(0, 0), stopwatchface_chrTiles, sizeof(stopwatchface_chrTiles));
  bitunpack2(PATRAM4(0, 64), stopwatchdigits_chrTiles, sizeof(stopwatchdigits_chrTiles));
  bitunpack2(SPR_VRAM(0), stopwatchhand_chrTiles, sizeof(stopwatchhand_chrTiles));
  load_flat_map(&(MAP[PFMAP][6][9]), stopwatchface_chrMap, 12, 13);
  vwfDrawLabels(sw_labels, 23, 0x4080);
  
  // Draw colons
  for (int i = 2; i < 8; i += 2) {
    unsigned int x = sw_digitx[i] + 2;
    MAP[PFMAP][4][x] = MAP[PFMAP][3][x] = 0x107C;
  };
  
  // Draw ruler
  for (int i = 0; i < 20; ++i) {
    MAP[PFMAP][i][1 + (i & 0x01)] = 0x7D;
  }

  do {
    read_pad_help_check(helpsect_stopwatch);

    if (new_keys & KEY_A) {
      running = !running;
    }
    if (new_keys & KEY_SELECT) {
      if (running || is_lap) {
        is_lap = !is_lap;
      } else {
        // Reset
        for (int i = 0; i < NUM_DIGITS; ++i) {
          digits[i] = 0;
        }
      }
    }
    if (new_keys & KEY_UP) {
      // 0: off; 3: on; 1: on during even framess
      show_ruler = (show_ruler - 1) & 0x03;
      if (show_ruler == 2) show_ruler = 1;
    }
    if (new_keys & KEY_DOWN) {
      hide_face = !hide_face;
    }
    
    if (running) {
      for (unsigned int i = 0; i < NUM_DIGITS; ++i) {
        digits[i] += 1;
        if (digits[i] >= sw_digitmax[i]) {
          digits[i] = 0;
        } else {
          break;
        }
      }
    }

    if (!is_lap) face_phase = digits[0];
    oam_used = 0;
    draw_stopwatch_hand(face_phase);
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    BG_COLORS[0] = RGB5(31, 31, 31);
    BG_COLORS[1] = hide_face ? RGB5(31, 31, 31) : RGB5(23, 23, 23);
    BG_COLORS[3] = (show_ruler & (1 << (face_phase & 1)))
                   ? RGB5(23, 0, 0) : RGB5(31, 31, 31);
    BG_COLORS[65] = RGB5(0, 0, 0);
    dmaCopy(invgray4pal, BG_COLORS+0x10, sizeof(invgray4pal));
    dmaCopy(bluepalette, BG_COLORS+0x21, sizeof(invgray4pal));
    dmaCopy(redpalette, BG_COLORS+0x31, sizeof(invgray4pal));
    dmaCopy(invgray4pal, OBJ_COLORS+0x00, sizeof(invgray4pal));
    ppu_copy_oam();

    // Update digits
    if (!is_lap) {
      for (int i = 0; i < NUM_DIGITS; ++i) {
        unsigned int tilenum = 64 + 6 * digits[i];
        unsigned int x = sw_digitx[i];
        if (i >= 2) {
          tilenum += 0x1000;  // Black digits
        } else {
          tilenum += (digits[0] & 1) ? 0x3000 : 0x2000;  // colored digits
        }
        for (unsigned int row = 2; row < 5; ++row) {
          MAP[PFMAP][row][x] = tilenum++;
          MAP[PFMAP][row][x + 1] = tilenum++;
        }
      }
      MAP[PFMAP][5][22] = MAP[PFMAP][5][23] = 0;
    } else {
      MAP[PFMAP][5][22] = 0x107E;  // LA
      MAP[PFMAP][5][23] = 0x107F;  // P
    }
  } while (!(new_keys & KEY_B));
}
