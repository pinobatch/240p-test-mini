/*
Static test patterns for 160p Test Suite
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
#include <stdint.h>
#include "global.h"
#include "4bcanvas.h"
#include "posprintf.h"

#include "monoscope_chr.h"
#include "sharpness_chr.h"
#include "convergence_chr.h"
#include "pluge_shark_6color_chr.h"

#define PFMAP 23
#define PFOVERLAY 22

static const unsigned short pluge_shark_dark[] = {
  RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 2, 2, 2),
  RGB5( 2, 2, 2),RGB5( 4, 4, 4)
};
static const unsigned short pluge_shark_darker[] = {
  RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 1, 1, 1),
  RGB5( 1, 1, 1),RGB5( 2, 2, 2)
};
static const unsigned short pluge_shark_light[] = {
  RGB5(27,27,27),RGB5(29,29,29),RGB5(29,29,29),RGB5(31,31,31),
  RGB5(31,31,31),RGB5(31,31,31)
};
static const unsigned short pluge_shark_lighter[] = {
  RGB5(29,29,29),RGB5(30,30,30),RGB5(30,30,30),RGB5(31,31,31),
  RGB5(31,31,31),RGB5(31,31,31)
};
static const unsigned short *const pluge_shark_palettes[] = {
  pluge_shark_6color_chrPal,
  pluge_shark_dark, pluge_shark_darker,
  pluge_shark_light, pluge_shark_lighter
};

const unsigned short gray4pal[4] = {
  RGB5( 0, 0, 0),RGB5(15,15,15),RGB5(23,23,23),RGB5(31,31,31)
};
const unsigned short invgray4pal[4] = {
  RGB5(31,31,31),RGB5(23,23,23),RGB5(15,15,15),RGB5( 0, 0, 0)
};
static const unsigned short smptePalettes[][13] = {
  {
    // 75% with setup
    RGB5( 2, 2, 2),RGB5( 2, 2,24),RGB5(24, 2, 2),RGB5(24, 2,24),
    RGB5( 2,24, 2),RGB5( 2,24,24),RGB5(24,24, 2),RGB5(24,24,24),
    RGB5( 6, 0,13),RGB5(31,31,31),RGB5( 0, 4, 6),RGB5( 1, 1, 1),
    RGB5( 3, 3, 3)
  },
  {
    // 75% without setup
    RGB5( 0, 0, 0),RGB5( 0, 0,23),RGB5(23, 0, 0),RGB5(23, 0,23),
    RGB5( 0,23, 0),RGB5( 0,23,23),RGB5(23,23, 0),RGB5(23,23,23),
    RGB5( 6, 0,13),RGB5(31,31,31),RGB5( 0, 4, 6),RGB5( 0, 0, 0),
    RGB5( 1, 1, 1)

  },
  {
    // 100% with setup
    RGB5( 2, 2, 2),RGB5( 2, 2,31),RGB5(31, 2, 2),RGB5(31, 2,31),
    RGB5( 2,31, 2),RGB5( 2,31,31),RGB5(31,31, 2),RGB5(31,31,31),
    RGB5( 6, 0,13),RGB5(31,31,31),RGB5( 0, 4, 6),RGB5( 1, 1, 1),
    RGB5( 3, 3, 3)
  },
  {
    // 100% without setup
    RGB5( 0, 0, 0),RGB5( 0, 0,31),RGB5(31, 0, 0),RGB5(31, 0,31),
    RGB5( 0,31, 0),RGB5( 0,31,31),RGB5(31,31, 0),RGB5(31,31,31),
    RGB5( 6, 0,13),RGB5(31,31,31),RGB5( 0, 4, 6),RGB5( 0, 0, 0),
    RGB5( 1, 1, 1)
  },
};
static const unsigned short plugePaletteNTSC[] = {
  RGB5( 2, 2, 2),RGB5( 3, 3, 3),RGB5( 0, 0, 0),RGB5( 0, 0, 0),
  RGB5(13,13,13),RGB5(19,19,19),RGB5(25,25,25),RGB5(31,31,31)
};
static const unsigned short plugePaletteNTSCJ[] = {
  RGB5( 0, 0, 0),RGB5( 1, 1, 1),RGB5( 1, 0, 1),RGB5( 0, 1, 0),
  RGB5(13,13,13),RGB5(19,19,19),RGB5(25,25,25),RGB5(31,31,31)
};
static const unsigned short brickspal[] = {
  RGB5( 5, 0, 0),RGB5(10, 5, 5),RGB5(15,15,10)
};
static const uint32_t brickstile[8] = {
  0x22111111,
  0x11221111,
  0x11112211,
  0x01111022,
  0x22011102,
  0x11221002,
  0x11112202,
  0x11111122,
};

static const uint16_t monoscope_whites[] = {
  RGB5( 0, 0, 0),RGB5(13,13,13),RGB5(22,22,22),RGB5(31,31,31),RGB5(31,31,31)
};

void activity_monoscope(void) {
  unsigned int brightness = 1;

  bitunpack2(tile_mem[0][0].data, monoscope_chrTiles, sizeof(monoscope_chrTiles));
  RLUnCompVram(monoscope_chrMap, se_mat[PFMAP]);

  while (1) {
    read_pad_help_check(helpsect_monoscope);
    if (new_keys & KEY_UP) {
      if (++brightness >= 5) brightness = 0;
    }
    if (new_keys & KEY_DOWN) {
      if (!brightness--) brightness = 4;
    }
    if (new_keys & KEY_B) {
      return;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    pal_bg_mem[0] = (brightness >= 4) ? RGB5(13,13,13) : 0;
    pal_bg_mem[1] = monoscope_whites[brightness];
    pal_bg_mem[2] = RGB5(31, 0, 0);
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
  }
}

#define TILE_SHARPNESS_BRICK_POSITION 128

void activity_sharpness(void) {
  unsigned int inverted = 0;
  unsigned int is_bricks = 0;

  bitunpack2(tile_mem[0][0].data, sharpness_chrTiles, sizeof(sharpness_chrTiles));
  RLUnCompVram(sharpness_chrMap, se_mat[PFMAP]);
  tonccpy(tile_mem[0][TILE_SHARPNESS_BRICK_POSITION].data, brickstile, sizeof(brickstile));
  dma_memset16(se_mat[PFOVERLAY], 0x0400 | TILE_SHARPNESS_BRICK_POSITION, 32*(SCREEN_HEIGHT>>3)*2);

  while (1) {
    read_pad_help_check(helpsect_sharpness);
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      return;
    }
    if (new_keys & KEY_A) {
      is_bricks = !is_bricks;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)
                |BG_SBB(is_bricks ? PFOVERLAY : PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    const unsigned short *palsrc = inverted ? invgray4pal : gray4pal;
    if (is_bricks) palsrc = brickspal;
    tonccpy(pal_bg_mem+0x00, palsrc, sizeof(gray4pal));
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
  }
}

static const BarsListEntry smpterects[] = {
  { 0, 0,GET_SLICE_X(SCREEN_WIDTH, 7, 1),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 7},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 1), 0,GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 6},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 2), 0,GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 3), 0,GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 4},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 4), 0,GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 5), 0,GET_SLICE_X(SCREEN_WIDTH, 7, 6),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 2},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 6), 0,SCREEN_WIDTH,GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), 1},

  { 0,GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10), GET_SLICE_X(SCREEN_WIDTH, 7, 1),GET_SLICE_X(SCREEN_HEIGHT, 4, 3), 1},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10),GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 4, 3), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10),GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 4, 3), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 6),GET_SLICE_X(SCREEN_HEIGHT, 4, 3)-(SCREEN_HEIGHT/10),SCREEN_WIDTH,GET_SLICE_X(SCREEN_HEIGHT, 4, 3), 7},

  { 0,GET_SLICE_X(SCREEN_HEIGHT, 4, 3),GET_SLICE_X(44 * SCREEN_WIDTH, GBA_SCREEN_WIDTH, 1),SCREEN_HEIGHT,10},
  {GET_SLICE_X(44 * SCREEN_WIDTH, GBA_SCREEN_WIDTH, 1),GET_SLICE_X(SCREEN_HEIGHT, 4, 3),GET_SLICE_X(44 * SCREEN_WIDTH, GBA_SCREEN_WIDTH, 2),SCREEN_HEIGHT, 9},
  {GET_SLICE_X(44 * SCREEN_WIDTH, GBA_SCREEN_WIDTH, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 3),GET_SLICE_X(44 * SCREEN_WIDTH, GBA_SCREEN_WIDTH, 3),SCREEN_HEIGHT, 8},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 4, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 5) + GET_SLICE_X(GET_SLICE_X(SCREEN_WIDTH, 7, 6) - GET_SLICE_X(SCREEN_WIDTH, 7, 5), 3, 1),SCREEN_HEIGHT,11},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 5) + GET_SLICE_X(GET_SLICE_X(SCREEN_WIDTH, 7, 6) - GET_SLICE_X(SCREEN_WIDTH, 7, 5), 3, 2),GET_SLICE_X(SCREEN_HEIGHT, 4, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 6),SCREEN_HEIGHT,12},

  {-1}
};

static const BarsListEntry cbogrects[] = {
  { 0, 0,SCREEN_WIDTH,SCREEN_HEIGHT, 7},

  {GET_SLICE_X(SCREEN_WIDTH, 7, 1),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 6},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 4},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),GET_SLICE_X(SCREEN_WIDTH, 7, 6),GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 2},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 6),GET_SLICE_X(SCREEN_HEIGHT, 5, 1),SCREEN_WIDTH,GET_SLICE_X(SCREEN_HEIGHT, 5, 2), 1},

  { 0,GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 1),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 1},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 1),GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 2},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 2),GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 3},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 3),GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 4},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 4),GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 5},
  {GET_SLICE_X(SCREEN_WIDTH, 7, 5),GET_SLICE_X(SCREEN_HEIGHT, 5, 3),GET_SLICE_X(SCREEN_WIDTH, 7, 6),GET_SLICE_X(SCREEN_HEIGHT, 5, 4), 6},

  {-1}
};

static const BarsListEntry plugerects[] = {
  { 16,  8, 32,SCREEN_HEIGHT-8, 1},  // Left outer bar

  {SCREEN_WIDTH-32,  8,SCREEN_WIDTH-16,SCREEN_HEIGHT-8, 1},  // Right outer bar

  // Inner bar is drawn separately

  { 80,  8,SCREEN_WIDTH-80, 8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 1), 7},  // light grays
  { 80, 8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 1),SCREEN_WIDTH-80, 8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 2), 6},
  { 80, 8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 2),SCREEN_WIDTH-80,8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 3), 5},
  { 80,8+GET_SLICE_X(SCREEN_HEIGHT-16, 4, 3),SCREEN_WIDTH-80,SCREEN_HEIGHT-8, 4},

  {-1}
};

void draw_barslist(const BarsListEntry *rects) {
  canvasInit(&screen, 0);
  for(; rects->l < SCREEN_WIDTH; ++rects) {
    canvasRectfill(&screen,
                   rects->l, rects->t, rects->r, rects->b,
                   rects->color);
  }
}

static void do_bars(const BarsListEntry *rects, helpdoc_kind helpsect) {
  unsigned int bright = 0, beep = 0;

  draw_barslist(rects);

  // Init sound to play 1 kHz tone
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;  // 4200: 65.5 kHz PWM (for PCM); C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND3CNT_L = 0;  // unlock waveram
  tonccpy((void *)REG_WAVE_RAM, waveram_sin2x, 16);
  REG_SOUND3CNT_L = 0xC0;    // lock waveram
  REG_SOUND3CNT_H = 0;       // volume control
  REG_SOUND3CNT_X = (2048 - 131) + 0x8000;  // full volume
  while (1) {
    read_pad_help_check(helpsect);
    if (new_keys & KEY_UP) {
      bright ^= 2;
    }
    if (new_keys & KEY_A) {
      bright ^= 1;
    }
    if (new_keys & KEY_SELECT) {
      beep = beep ^ 0x2000;
    }
    if (new_keys & KEY_B) {
      REG_SOUNDCNT_X = 0;  // turn sound off
      return;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    tonccpy(pal_bg_mem+0x00, smptePalettes[bright], sizeof(smptePalettes[0]));
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
    REG_SOUND3CNT_H = beep;
  }
}

void activity_smpte(void) {
  do_bars(smpterects, helpsect_smpte_color_bars);
}

void activity_601bars(void) {
  do_bars(cbogrects, helpsect_color_bars_on_gray);
}

void activity_pluge(void) {
  unsigned int bright = 0;
  unsigned int shark = 0;

  draw_barslist(plugerects);

  // PLUGE rects is missing checkerboard stipples of colors 2 and 3
  // at (48, 8)-(64, 152) and (176, 8)-(192, 152)
  for (unsigned int x = 6; x < ((SCREEN_WIDTH >> 3) - 6); x += 1) {
    if (x == 8) x = ((SCREEN_WIDTH >> 3) - 8);
    unsigned int stride = screen.height * 8;
    uint32_t *tile = screen.chrBase + stride * x + 8;
    for (unsigned int yleft = ((SCREEN_HEIGHT - 16) / 2); yleft > 0; --yleft) {
      *tile++ = 0x23232323;
      *tile++ = 0x32323232;
    }
  }
  
  LZ77UnCompVram(pluge_shark_6color_chrTiles, tile_mem[0][(SCREEN_HEIGHT >> 3) * 32].data);
  for (unsigned int y = 0; y < (SCREEN_HEIGHT >> 3); ++y) {
    for (unsigned int x = 0; x < (SCREEN_WIDTH >> 3); ++x) {
      se_mat[PFOVERLAY][y][x] = ((SCREEN_HEIGHT >> 3) * 32) + ((y & 0x03) << 2) + ((x + (((SCREEN_WIDTH % 32) >> 3) / 2)) & 0x03);
    }
  }

  while (1) {
    read_pad_help_check(helpsect_pluge);
    if (new_keys & KEY_A) {
      bright += 1;
      if (bright >= (shark ? 5 : 2)) bright = 0;
    }
    if (new_keys & KEY_SELECT) {
      shark = !shark;
      bright = 0;
    }
    if (new_keys & KEY_B) {
      return;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(shark ? PFOVERLAY : PFMAP);
    REG_BG_OFS[0].y = REG_BG_OFS[0].x = 0;
    if (shark) {
      tonccpy(pal_bg_mem+0x00, pluge_shark_palettes[bright],
              sizeof(pluge_shark_6color_chrPal));
    } else {
      tonccpy(pal_bg_mem+0x00, bright ? plugePaletteNTSCJ : plugePaletteNTSC,
              sizeof(plugePaletteNTSC));
    }
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
  }
}

static const unsigned short gcbars_palramps[4] = {
  RGB5(1, 0, 0),
  RGB5(0, 1, 0),
  RGB5(0, 0, 1),
  RGB5(1, 1, 1)
};

#define NUM_PIXELS_PER_GCBAR_PIECE ((SCREEN_WIDTH - 64) / 32)
#define START_TILE_GCBAR_PIECE (6 + (((SCREEN_WIDTH >> 3) - 8) - (4 * NUM_PIXELS_PER_GCBAR_PIECE)))
#define NUM_Y_TILES_GCBAR_PIECE (((SCREEN_HEIGHT >> 3) - 8) / 4)

static const char gcbars_positions[] = {
    (START_TILE_GCBAR_PIECE*8), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (1 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (2 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (3 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (4 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (5 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (6 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    (START_TILE_GCBAR_PIECE*8) + (7 * NUM_PIXELS_PER_GCBAR_PIECE * 4), 0x10,
    0x10, 0x18,
    0x10, 0x18 + (1 * (NUM_Y_TILES_GCBAR_PIECE + 1) * 8),
    0x10, 0x18 + (2 * (NUM_Y_TILES_GCBAR_PIECE + 1) * 8),
    0x10, 0x18 + (3 * (NUM_Y_TILES_GCBAR_PIECE + 1) * 8)
};

static const char gcbars_labels[] =
  "0\n"
  "2\n"
  "4\n"
  "6\n"
  "8\n"
  "A\n"
  "C\n"
  "E\n"
  "Red\n"
  "Green\n"
  "Blue\n"
  "White";

static void draw_gcbars(const TileCanvas* graiety) {
  canvasInit(graiety, 1);
  for (unsigned int i = 0; i < 8; ++i) {
    canvasRectfill(graiety,
                   NUM_PIXELS_PER_GCBAR_PIECE * i, 0, NUM_PIXELS_PER_GCBAR_PIECE * (i + 1), 8,
                   i + 8);
  }

  // Draw map
  dma_memset16(graiety->mapBase[PFMAP], 0x0004, 32*(SCREEN_HEIGHT >> 3)*2);
  unsigned int starttn = 0x40 - NUM_PIXELS_PER_GCBAR_PIECE;
  for (unsigned int y = 3, counter = 0; y < (SCREEN_HEIGHT >> 3) - 2; ++y) {

    unsigned int tn = starttn;
    for (unsigned int x = START_TILE_GCBAR_PIECE; x < (SCREEN_WIDTH >> 3) - 2; ++x) {
      graiety->mapBase[PFMAP][y][x] = tn;
      if ((++tn & 0xFF) == 0x40) {
        tn += 0x1000 - NUM_PIXELS_PER_GCBAR_PIECE;
      }
    }

    ++counter;
    if(counter == NUM_Y_TILES_GCBAR_PIECE) {
      counter = 0;
      ++y;
      starttn += 0x4000;
    }
  }
  
  // Draw secondary map (with grid)
  for (unsigned int y = 0; y < (SCREEN_HEIGHT >> 3); ++y) {
    for (unsigned int x = 0; x < 32; ++x) {
      unsigned int tilenum = graiety->mapBase[PFMAP][y][x];
      if (tilenum <= 4) {
        tilenum = 0x20;
        if (x & 1) tilenum |= 0x400;
        if (y & 1) tilenum |= 0x800;
      }
      graiety->mapBase[PFOVERLAY][y][x] = tilenum;
    }
  }
}

void activity_gcbars(void) {
  unsigned int REG_BGCNT0 = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);

  load_common_bg_tiles();
  // Draw 5-pixel-wide vertical bars
  static const TileCanvas graiety = {
    8, 1, NUM_PIXELS_PER_GCBAR_PIECE, 1, tile_mem[0][0x40 - NUM_PIXELS_PER_GCBAR_PIECE].data, PFMAP, 0, 0x40 - NUM_PIXELS_PER_GCBAR_PIECE, se_mat
  };
  draw_gcbars(&graiety);
  
  // Draw labels on primary map
  vwfDrawLabelsPositionBased(gcbars_labels, gcbars_positions, PFMAP, 0x40);

  while (1) {
    read_pad_help_check(helpsect_gradient_color_bars);
    if (new_keys & KEY_B) {
      return;
    }
    if (new_keys & KEY_A) {
      REG_BGCNT0 ^= BG_SBB(PFMAP) ^ BG_SBB(PFOVERLAY);
    }

    VBlankIntrWait();
    REG_BGCNT[0] = REG_BGCNT0;
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    pal_bg_mem[0] = RGB5(0, 0, 0);
    pal_bg_mem[1] = RGB5(31, 31, 31);

    // Calculate the color gradient
    unsigned int c = 0;
    const unsigned short *palramp = gcbars_palramps;
    for (unsigned int p = 8; p < 256; ++p) {
      if ((p & 0x0F) == 0) {
        p += 8;
        if ((p & 0x30) == 0) {
          ++palramp;
          c = 0;
        }
      }
      pal_bg_mem[p] = c;
      c += *palramp;
    }
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
  }
}

#define GRAY_RAMP_PIXELS (SCREEN_WIDTH / 32)
#define GRAY_RAMP_TILES (GRAY_RAMP_PIXELS + 1)
#define GRAY_RAMP_START_TILE ((((SCREEN_WIDTH >> 3) - ((SCREEN_WIDTH / 32) * 4)) + 1) / 2)
#define GRAY_RAMP_END_TILE ((SCREEN_WIDTH >> 3) - (((SCREEN_WIDTH >> 3) - ((SCREEN_WIDTH / 32) * 4)) / 2))

static void draw_gray_ramp(const TileCanvas* graiety) {
  canvasInit(graiety, 1);
  for (unsigned int i = 0; i < 8; ++i) {
    canvasRectfill(graiety,
                   8 + GRAY_RAMP_PIXELS * i, 0, 8 + GRAY_RAMP_PIXELS * (i + 1), 8,
                  i + 1);
  }

  // Draw map
  dma_memset16(graiety->mapBase[PFMAP], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  for (unsigned int y = 1; y < (SCREEN_HEIGHT >> 4); ++y) {
    unsigned int tn = 0x0001;
    for (unsigned int x = GRAY_RAMP_START_TILE; x < GRAY_RAMP_END_TILE; ++x) {
      graiety->mapBase[PFMAP][y][x] = tn;
      graiety->mapBase[PFMAP][y + (SCREEN_HEIGHT >> 4) - 1][GRAY_RAMP_END_TILE - 1 + GRAY_RAMP_START_TILE - x] = tn | 0x0400;
      if ((++tn & 0x0F) == GRAY_RAMP_TILES) {
        tn += 0x1001 - GRAY_RAMP_TILES;
      }
    }
  }
}

void activity_gray_ramp(void) {

  // Draw 7-pixel-wide vertical bars
  static const TileCanvas graiety = {
    0, 1, GRAY_RAMP_TILES, 1, tile_mem[0][0].data, PFMAP, 0, 0, se_mat
  };
  draw_gray_ramp(&graiety);
  
  // TODO: Make the tilemap with palette for the custom canvas
  while (1) {
    read_pad_help_check(helpsect_gray_ramp);
    if (new_keys & KEY_B) {
      REG_BLDCNT = 0;
      return;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    
    unsigned int c = 0;
    for (unsigned int p = 1; p < 64; ++p) {
      pal_bg_mem[p] = c;
      c += RGB5(1, 1, 1);
      if ((p & 0x0F) == 8) p += 8;
    }
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
  }
}

static const uint32_t full_stripes_patterns[3][2] = {
  {0x11111111,0x22222222},
  {0x12121212,0x12121212},
  {0x12121212,0x21212121}
};

static const unsigned short full_stripes_colors[10][2] = {
  { RGB5(31, 0, 0), 0 },
  { RGB5(31,31, 0), 0 },
  { RGB5( 0,31, 0), 0 },
  { RGB5( 0,31,31), 0 },
  { RGB5( 0, 0,31), 0 },
  { RGB5(31, 0,31), 0 },
  { RGB5(31,31,31), 0 },
  { RGB5(31,31,31), 0 },
  { RGB5(16,16,16), 0 },
  { RGB5(31, 0, 0), RGB5( 0, 0,31) }
};


static void do_full_stripes(helpdoc_kind helpsect) {
  unsigned int pattern = 0, inverted = 0, frame = 0;
  unsigned int lcdcvalue = DCNT_MODE1 | DCNT_BG1 | ACTIVATE_SCREEN_HW;

  // tile 0: blank
  dma_memset16(tile_mem[0][0].data, 0x0000, 32);

  // row 19: frame counter
  dma_memset16(se_mat[PFOVERLAY], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  loadMapRowMajor(&(se_mat[PFOVERLAY][(SCREEN_HEIGHT >> 3) - 1][(SCREEN_WIDTH >> 3) - 6]), 0x6002, 6, 1);

  while (1) {
    read_pad_help_check(helpsect);
    autorepeat(KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT);
    if (das_timer <= 3) das_timer = 1;
    if (new_keys & KEY_A) {
      if (++pattern >= 3) pattern = 0;
    }
    if (new_keys & KEY_SELECT) {
      lcdcvalue ^= DCNT_BG0;
    }
    if (new_keys & (KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT)) {
      inverted ^= 0x33333333;
    }
    if (new_keys & KEY_B) {
      return;
    }

    if (++frame >= 60) frame = 0;
    posprintf(help_line_buffer, "Frame %02d", frame);

    VBlankIntrWait();
    REG_BGCNT[1] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFOVERLAY);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = REG_BG_OFS[1].x = 0;
    if(((SCREEN_HEIGHT >> 3) - 4) % 5)
        REG_BG_OFS[1].y = 4;
    else
        REG_BG_OFS[1].y = 8;
    pal_bg_mem[0] = RGB5(0, 0, 0);
    for (int c = 0; c < 10; ++c) {
      pal_bg_mem[c * 16 + 1] = full_stripes_colors[c][0];
      pal_bg_mem[c * 16 + 2] = full_stripes_colors[c][1];
    }
    REG_DISPCNT = lcdcvalue;

    // Draw the pattern
    u32 *dst = tile_mem[0][1].data;
    for (unsigned int i = 4; i > 0; --i) {
      *dst++ = full_stripes_patterns[pattern][0] ^ inverted;
      *dst++ = full_stripes_patterns[pattern][1] ^ inverted;
    }

    // Draw the frame counter
    dma_memset16(tile_mem[0][2].data, 0x2222, 32*6);
    vwf8Puts(tile_mem[0][2].data, help_line_buffer, 4, 1);
  }
}

void activity_full_stripes(void) {
  // Clear the screen
  dma_memset16(se_mat[PFMAP], 0x6001, 32*((SCREEN_HEIGHT >> 3) + 1)*2);
  do_full_stripes(helpsect_full_screen_stripes);
}

static void draw_stripe_regions(SCREENMAT *map_address) {
  // Draw stripe regions
  for (unsigned int sy = 0; sy < 5; ++sy) {
    for (unsigned int sx = 0; sx < 2; ++sx) {
      unsigned short *src = &(map_address[PFMAP][sy * ((((SCREEN_HEIGHT >> 3) - 4) / 5) + 1) + 1][sx * (SCREEN_WIDTH >> 4) + 1]);
      unsigned int tilenum = ((sy * 2 + sx) << 12) + 1;
      for (unsigned int j = 0; j < (((SCREEN_HEIGHT >> 3) - 4) / 5); j++) {
        dma_memset16(src + (j * 32), tilenum, ((SCREEN_WIDTH >> 4) - 2)*2);
      }
    }
  }
}

void activity_color_bleed(void) {
  // Clear the screen
  dma_memset16(se_mat[PFMAP], 0x0000, 32*((SCREEN_HEIGHT >> 3) + 1)*2);
  draw_stripe_regions(se_mat);
  do_full_stripes(helpsect_color_bleed);
}

static const unsigned short solid_colors[4] = {
  RGB5( 0, 0, 0),
  RGB5(31, 0, 0),
  RGB5( 0,31, 0),
  RGB5( 0, 0,31)
};

static const unsigned char rgbnames[3] = {'R', 'G', 'B'};

static void solid_color_draw_edit_box(const unsigned char rgb[3], unsigned int y, TILE* target_tile_mem) {
  dma_memset16(target_tile_mem[1].data, 0x2222, 32*9);
  for (unsigned int i = 0; i < 3; ++i) {
    uint32_t *dst = (uint32_t*)(target_tile_mem[3 * i + 1].data);

    // Draw label
    if (i == y) vwf8PutTile(dst, '>', 1, 1);
    vwf8PutTile(dst, rgbnames[i], 6, 1);

    // Draw component value
    unsigned int value = rgb[i];
    uint32_t tens = value / 10;
    if (tens > 0) vwf8PutTile(dst, tens + '0', 14, 1);
    vwf8PutTile(dst, (value - tens * 10) + '0', 19, 1);
  }
}

void activity_solid_color(void) {
  unsigned int showeditbox = 0, x = 4, y = 0;
  unsigned char rgb[3] = {31, 31, 31};

  // Clear the screen
  dma_memset16(se_mat[PFMAP], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  dma_memset16(tile_mem[0][0].data, 0x0000, 32);

  // Allocate canvas for the RGB editing box
  loadMapRowMajor(&(se_mat[PFMAP][1][26]), 0x0001, 3, 3);

  while (1) {
    read_pad_help_check(helpsect_solid_color_screen);
    if ((new_keys & KEY_A) && (x == 4)) {
      showeditbox = !showeditbox;
    }
    if (new_keys & KEY_B) {
      return;
    }
    if (showeditbox) {
      autorepeat(KEY_LEFT|KEY_RIGHT);
      if ((new_keys & KEY_UP) && y > 0) {
        --y;
      }
      if ((new_keys & KEY_DOWN) && y < 2) {
        ++y;
      }
      if ((new_keys & KEY_LEFT) && rgb[y] > 0) {
        --rgb[y];
      }
      if ((new_keys & KEY_RIGHT) && rgb[y] < 31) {
        ++rgb[y];
      }
      solid_color_draw_edit_box(rgb, y, &tile_mem[0][0]);
    } else {
      if (new_keys & KEY_RIGHT) {
        x += 1;
        if (x >= 5) x = 0;
      }
      if (new_keys & KEY_LEFT) {
        x = (x ? x : 5) - 1;
      }
    }

    VBlankIntrWait();
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    pal_bg_mem[0] = x < 4 ? solid_colors[x] : RGB5(rgb[0], rgb[1], rgb[2]);
    pal_bg_mem[1] = RGB5(31, 31, 31);
    pal_bg_mem[2] = RGB5(0, 0, 0);
    REG_DISPCNT = showeditbox ? (DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW) : ACTIVATE_SCREEN_HW;
  }
}

void activity_convergence(void) {
  unsigned char cur_side = 0;
  unsigned char gridinvert = 0;
  unsigned char griddepth = 0;
  unsigned char colors_border = 0;

  bitunpack2(tile_mem[0][0].data, convergence_chrTiles, sizeof(convergence_chrTiles));
  dma_memset16(se_mat[PFMAP], 0x04, 32*(SCREEN_HEIGHT >> 3)*2); 
  for (unsigned int y = 0; y < (SCREEN_HEIGHT >> 3); ++y) {
    unsigned int rowtilebase = (((y & 3) == 3) << 1) | ((y & 4) ? 0x2000 : 0);
    for (unsigned int x = 0; x < (SCREEN_WIDTH >> 3); ++x) {
      unsigned int tile = ((x & 3) == 3) | ((x & 4) ? 0x1000 : 0) | rowtilebase;
      se_mat[PFOVERLAY][y][x] = tile;
    }
  }

  while (1) {
    read_pad_help_check(helpsect_convergence);

    if (new_keys & KEY_A) cur_side = !cur_side;
    if (new_keys & KEY_SELECT) gridinvert = !gridinvert;
    if (new_keys & KEY_B) return;
    if (cur_side != 0) {
      // Color transition boundary: Toggle border
      if (new_keys & (KEY_UP | KEY_DOWN)) {
        colors_border = !colors_border;
      }
    } else {
      if (new_keys & KEY_UP) griddepth += 2;
      if (new_keys & KEY_DOWN) griddepth += 1;
      if (griddepth >= 3) griddepth -= 3;
    }

    VBlankIntrWait();
    REG_BGCNT[0] = (BG_4BPP|BG_SIZE0|BG_CBB(0)
                 |BG_SBB(PFMAP-cur_side));
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | ACTIVATE_SCREEN_HW;
    if (cur_side != 0) {
      pal_bg_mem[0x03] = RGB5(31,31,31);
      pal_bg_mem[0x13] = RGB5( 0, 0,31);
      pal_bg_mem[0x23] = RGB5( 0,31, 0);
      pal_bg_mem[0x33] = RGB5(31, 0, 0);
      pal_bg_mem[0x02] = colors_border ? 0 : RGB5(31,31,31);
      pal_bg_mem[0x12] = colors_border ? 0 : RGB5( 0, 0,31);
      pal_bg_mem[0x22] = colors_border ? 0 : RGB5( 0,31, 0);
      pal_bg_mem[0x32] = colors_border ? 0 : RGB5(31, 0, 0);
    } else {
      // Set palette for grid
      unsigned int color = gridinvert ? 0x7FFF : 0;
      for (unsigned int i = 0; i < 4; ++i) {
        pal_bg_mem[i] = color;
        if (i == griddepth) color = color ^ 0x7FFF;
      }
    }
  }

}
