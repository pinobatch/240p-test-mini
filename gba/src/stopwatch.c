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
#include <tonc.h>

#include "stopwatchhand_chr.h"
#include "stopwatchface_chr.h"
#include "stopwatchdigits_chr.h"

#define PFMAP 23
#define TIMEMAP 22
#define NUM_DIGITS 8
#define NUM_FACE_PHASES 10

#define START_TILE_SW_X ((SCREEN_WIDTH >> 4) - 9)
#define NUM_SW_X_TILES 19
#define DIGITS_OFFSET_X ((START_TILE_SW_X - ((SCREEN_WIDTH >> 3) - (START_TILE_SW_X + NUM_SW_X_TILES))) * 4)

static const unsigned char sw_digitmax[NUM_DIGITS] = {
  NUM_FACE_PHASES, 6, 10, 6, 10, 6, 10, 10
};

static const unsigned char sw_digitx[NUM_DIGITS] = {
  START_TILE_SW_X+17, START_TILE_SW_X+15, START_TILE_SW_X+12, START_TILE_SW_X+10, START_TILE_SW_X+7, START_TILE_SW_X+5, START_TILE_SW_X+2, START_TILE_SW_X
};

static const unsigned char sw_face_x[NUM_FACE_PHASES] = {
  (SCREEN_WIDTH / 2)-16, (SCREEN_WIDTH / 2)+6, (SCREEN_WIDTH / 2)+20, (SCREEN_WIDTH / 2)+20, (SCREEN_WIDTH / 2)+6, (SCREEN_WIDTH / 2)-16, (SCREEN_WIDTH / 2)-38, (SCREEN_WIDTH / 2)-52, (SCREEN_WIDTH / 2)-52, (SCREEN_WIDTH / 2)-38
};

// A small dot is drawn halfway between the center and the number on
// the face.  Its Y coordinate is slightly uneven because of rounding.
static const unsigned char sw_face_y[NUM_FACE_PHASES] = {
  58, 65, 84, 108, 127, 134, 127, 108, 84, 65
};

static const unsigned short bluepalette[3] = {
  RGB5(23,23,31),RGB5(15,15,31),RGB5( 0, 0,31)
};
static const unsigned short redpalette[3] = {
  RGB5(31,23,23),RGB5(31,15,15),RGB5(31, 0, 0)
};

static const char sw_positions[] = {
    (START_TILE_SW_X*8) + 7, 0x08,
    ((START_TILE_SW_X+5)*8) + 3, 0x08,
    ((START_TILE_SW_X+10)*8) + 2, 0x08,
    ((START_TILE_SW_X+15)*8) + 5, 0x08
};

static const char sw_labels[] =
  "hour\n"
  "minute\n"
  "second\n"
  "frame";

static void draw_stopwatch_hand(unsigned int phase) {
  unsigned int i = oam_used;
  unsigned int a0 = ATTR0_Y(sw_face_y[phase] - 12) | ATTR0_4BPP | ATTR0_SQUARE;
  unsigned int a1 = ATTR1_X(sw_face_x[phase]) | ATTR1_SIZE_16;

  // draw digit
  SOAM[i].attr0 = a0 + 8;
  SOAM[i].attr1 = a1 + 8;
  SOAM[i++].attr2 = phase * 4;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1 + 16 + ATTR1_HFLIP;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0 + 16;
  SOAM[i].attr1 = a1 + ATTR1_VFLIP;
  SOAM[i++].attr2 = 40;
  SOAM[i].attr0 = a0 + 16;
  SOAM[i].attr1 = a1 + 16 + ATTR1_HFLIP + ATTR1_VFLIP;
  SOAM[i++].attr2 = 40;

  // draw hand
  a0 = ATTR0_Y(sw_face_y[phase] / 2 + 48) | ATTR0_4BPP | ATTR0_SQUARE;
  a1 = ATTR1_X(sw_face_x[phase] / 2 + (SCREEN_WIDTH >> 2) + 4) | ATTR1_SIZE_8;
  SOAM[i].attr0 = a0;
  SOAM[i].attr1 = a1;
  SOAM[i++].attr2 = 44;

  oam_used = i;
}

void activity_stopwatch() {
  unsigned char digits[NUM_DIGITS] = {0};
  unsigned int running = 0, is_lap = 0, hide_face = 0, show_ruler = 0, face_phase = 0;

  dma_memset16(se_mat[PFMAP], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  dma_memset16(se_mat[TIMEMAP], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  bitunpack1(tile_mem[0][0].data, stopwatchface_chrTiles, sizeof(stopwatchface_chrTiles));
  bitunpack2(tile_mem[0][64].data, stopwatchdigits_chrTiles, sizeof(stopwatchdigits_chrTiles));
  bitunpack2(tile_mem_obj[0][0].data, stopwatchhand_chrTiles, sizeof(stopwatchhand_chrTiles));
  load_flat_map(&(se_mat[PFMAP][6][(SCREEN_WIDTH>>4)-6]), stopwatchface_chrMap, 12, 13);

  vwfDrawLabelsPositionBased(sw_labels, sw_positions, TIMEMAP, 0x4080);
  
  // Draw colons
  for (int i = 2; i < 8; i += 2) {
    unsigned int x = sw_digitx[i] + 2;
    se_mat[TIMEMAP][4][x] = se_mat[TIMEMAP][3][x] = 0x107C;
  };
  
  // Draw ruler
  for (int i = 0; i < (SCREEN_HEIGHT >> 3); ++i) {
    se_mat[PFMAP][i][1 + (i & 0x01)] = 0x7D;
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
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_BG1 | DCNT_OBJ_1D | DCNT_OBJ;
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BGCNT[1] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(TIMEMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = REG_BG_OFS[1].y = 0;
    REG_BG_OFS[1].x = DIGITS_OFFSET_X;
    pal_bg_mem[0] = RGB5(31, 31, 31);
    pal_bg_mem[1] = hide_face ? RGB5(31, 31, 31) : RGB5(23, 23, 23);
    bool final_show_ruler = (show_ruler & (1 << (face_phase & 1)));
    pal_bg_mem[3] = final_show_ruler ? RGB5(23, 0, 0) : RGB5(31, 31, 31);
    pal_bg_mem[65] = RGB5(0, 0, 0);
    tonccpy(pal_bg_mem+0x10, invgray4pal, sizeof(invgray4pal));
    tonccpy(pal_bg_mem+0x21, bluepalette, sizeof(bluepalette));
    tonccpy(pal_bg_mem+0x31, redpalette, sizeof(redpalette));
    tonccpy(pal_obj_mem+0x00, invgray4pal, sizeof(invgray4pal));
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
          se_mat[TIMEMAP][row][x] = tilenum++;
          se_mat[TIMEMAP][row][x + 1] = tilenum++;
        }
      }
      se_mat[TIMEMAP][5][START_TILE_SW_X+16] = se_mat[TIMEMAP][5][START_TILE_SW_X+17] = 0;
    } else {
      se_mat[TIMEMAP][5][START_TILE_SW_X+16] = 0x107E;  // LA
      se_mat[TIMEMAP][5][START_TILE_SW_X+17] = 0x107F;  // P
    }
  } while (!(new_keys & KEY_B));
}
