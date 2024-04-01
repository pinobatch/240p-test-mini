/*
Shadow sprite test for 160p Test Suite
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
#include <stdint.h>

#include "Donna_chr.h"
#include "Gus_portrait_chr.h"
#include "hepsie_chr.h"

#define PFSCROLLTEST 22
#define PFOVERLAY 21

static void gus_bg_setup(void) {
  LZ77UnCompVram(Gus_portrait_chrTiles, tile_mem[0][0].data);
  dma_memset16(se_mat[PFSCROLLTEST], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  load_flat_map(&(se_mat[PFSCROLLTEST][0][8]), Gus_portrait_chrMap, 14, SCREEN_HEIGHT >> 3);
}

static void gus_bg_set_scroll(uint16_t *hdmaTable, unsigned int unused) {
  (void)hdmaTable;
  (void)unused;
  REG_BGCNT[1] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFSCROLLTEST);
  REG_BG_OFS[1].x = 0;
  REG_BG_OFS[1].y = 0;
  tonccpy(pal_bg_mem, Gus_portrait_chrPal, sizeof(Gus_portrait_chrPal));
}

static void donna_bg_setup(void) {
  LZ77UnCompVram(Donna_chrTiles, tile_mem[0][0].data);
  dma_memset16(se_mat[PFSCROLLTEST], 0x0000, 32*(SCREEN_HEIGHT >> 3)*2);
  load_flat_map(&(se_mat[PFSCROLLTEST][0][0]), Donna_chrMap, (SCREEN_WIDTH >> 3), (SCREEN_HEIGHT >> 3));
}

#define DONNA_BG_COLORS BG_4BPP

static void donna_bg_set_scroll(uint16_t *hdmaTable, unsigned int unused) {
  (void)hdmaTable;
  (void)unused;
  REG_BGCNT[1] = DONNA_BG_COLORS|BG_SIZE0|BG_CBB(0)|BG_SBB(PFSCROLLTEST);
  REG_BG_OFS[1].x = 0;
  REG_BG_OFS[1].y = 0;
  tonccpy(pal_bg_mem, Donna_chrPal, sizeof(Donna_chrPal));
}

static void striped_bg_setup(unsigned int tilenum) {
  load_common_bg_tiles();
  dma_memset16(se_mat[PFSCROLLTEST], tilenum, 32*(SCREEN_HEIGHT >> 3)*2);
}

static void bg_2_setup() {
  striped_bg_setup(0x000A);
}

static void bg_3_setup() {
  striped_bg_setup(0x0000);
}

static void striped_bg_set_scroll(uint16_t *hdmaTable, unsigned int unused) {
  (void)hdmaTable;
  (void)unused;
  REG_BGCNT[1] = BG_4BPP|BG_SIZE0|BG_CBB(0)|BG_SBB(PFSCROLLTEST);
  REG_BG_OFS[1].x = 0;
  REG_BG_OFS[1].y = 0;
  pal_bg_mem[0] = pal_bg_mem[2] = 0;
  pal_bg_mem[3] = RGB5(31, 31, 31);
}

typedef struct ShadowSpriteBG {
  void (*setup)(void);
  void (*set_scroll)(uint16_t *hdmaTable, unsigned int x);
} ShadowSpriteBG;

static const ShadowSpriteBG bgtypes[] = {
  {gus_bg_setup, gus_bg_set_scroll},
  {donna_bg_setup, donna_bg_set_scroll},
  {hill_zone_load_bg, hill_zone_set_scroll},
  {bg_2_setup, striped_bg_set_scroll},
  {bg_3_setup, striped_bg_set_scroll},
};

#define NUM_BGTYPES (sizeof bgtypes / sizeof bgtypes[0])

static const unsigned short shadow_sprite_palettes[3][3] = {
  {RGB5( 0, 0, 0),RGB5( 0,31, 0),RGB5(31,25,19)},  // Hepsie top half
  {RGB5( 0, 0, 0),RGB5(31, 0,31),RGB5(31,31, 0)},  // Hepsie bottom half
  {RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 0, 0, 0)},  // Shadow
};

static const char *const shadow_sprite_types[] = {
  "even frames",
  "odd frames",
  "horiz. stripes",
  "vert. stripes",
  "checkerboard"
};

static void shadow_sprite_message(const char *s) {
  dma_memset16(tile_mem[2][1].data, 0x2222, 32*8);
  vwf8Puts(tile_mem[2][1].data, s, 3, 1);
}

static const unsigned char shadowmasks[3][2] = {
  {0x00,0xFF},  // horizontal lines
  {0xF0,0xF0},  // vertical lines
  {0xF0,0x0F},  // checkerboard
};

static void load_shadow_sprite(TILE *sprite_vram) {
  bitunpack2(sprite_vram, hepsie_chrTiles, sizeof(hepsie_chrTiles));
  // Generate stippled masks at 32, 64, and 96
  for (unsigned int maskid = 0; maskid < 3; ++maskid) {
    const u32 *src = (u32*)sprite_vram;
    u32 *dst = (u32*)(sprite_vram + 32 * (maskid + 1));
    u32 maskA = 0x01010101 * shadowmasks[maskid][0];
    u32 maskB = 0x01010101 * shadowmasks[maskid][1];
    
    for(int i = 0; i < 32 * 16; i++) {
      dst[2*i] = src[2*i] & maskA;
      dst[(2*i)+1] = src[(2*i)+1] & maskB;
    }
  }
}

void activity_shadow_sprite() {
  unsigned int held_keys = 0, x = (SCREEN_WIDTH - 32) >> 1, y = (SCREEN_HEIGHT - 32) >> 1, facing = 0;
  unsigned int cur_bg = 0, changetimeout = 0;
  unsigned int cur_shape = 0, shadow_type = 0, frame = 0;
  uint16_t hdmaTable[SCREEN_HEIGHT];

  dma_memset16(se_mat[PFOVERLAY], 0xF000, 32*((SCREEN_HEIGHT >> 3)+1)*2);
  loadMapRowMajor(&(se_mat[PFOVERLAY][SCREEN_HEIGHT >> 3][(SCREEN_WIDTH >> 3) - 8]), 0xF001, 8, 1);
  dma_memset16(tile_mem[2][0].data, 0x0000, 32*1);
  dma_memset16(tile_mem[2][1].data, 0x2222, 32*8);

  load_shadow_sprite(&tile_mem_obj[0][0]);
  
  bgtypes[cur_bg].setup();

  do {
    read_pad_help_check(helpsect_shadow_sprite);
    held_keys |= new_keys;
    
    frame = !frame;
    if (changetimeout > 0) --changetimeout;
    if (new_keys & KEY_SELECT) {
      cur_shape = !cur_shape;
    }
    if (cur_keys & KEY_A) {
      if (new_keys & KEY_RIGHT) {
        if (++cur_bg >= NUM_BGTYPES) cur_bg = 0;
        REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ;
        bgtypes[cur_bg].setup();
        held_keys &= ~KEY_A;
      }
      if (new_keys & KEY_LEFT) {
        cur_bg = cur_bg ? cur_bg - 1 : NUM_BGTYPES - 1;
        REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ;
        bgtypes[cur_bg].setup();
        held_keys &= ~KEY_A;
      }
      if (new_keys & KEY_UP) {
        shadow_type = (shadow_type < 2) ? 2 : 0;
        changetimeout = 68;
        shadow_sprite_message(shadow_sprite_types[shadow_type]);
        held_keys &= ~KEY_A;
      }
    } else {
      if (held_keys & KEY_A) {
        shadow_type += 1;
        if (shadow_type == 2) {
          shadow_type = 0;
        } else if (shadow_type >= 5) {
          shadow_type = 2;
        }
        changetimeout = 68;
        shadow_sprite_message(shadow_sprite_types[shadow_type]);
        held_keys &= ~KEY_A;
      }
      if ((cur_keys & KEY_RIGHT) && x < SCREEN_WIDTH - 32) {
        x += 1;
        facing = 0;
      }
      if ((cur_keys & KEY_LEFT) && x > 0) {
        x -= 1;
        facing = ATTR1_HFLIP;
      }
      if ((cur_keys & KEY_DOWN) && y < SCREEN_HEIGHT - 32) {
        y += 1;
      }
      if ((cur_keys & KEY_UP) && y > 0) {
        y -= 1;
      }
    }

    unsigned int i = 0, sx = x, sy = y;
    if (cur_shape) {
      // Draw the nontransparent part of Hepsie
      SOAM[i].attr0 = ATTR0_Y(y) | ATTR0_4BPP | ATTR0_WIDE;
      SOAM[i].attr1 = ATTR1_X(x - 4) | ATTR1_SIZE_32 | facing;
      SOAM[i].attr2 = 0x0010;
      ++i;
      SOAM[i].attr0 = ATTR0_Y(y + 16) | ATTR0_4BPP | ATTR0_WIDE;
      SOAM[i].attr1 = ATTR1_X(x - 4) | ATTR1_SIZE_32 | facing;
      SOAM[i].attr2 = 0x1018;
      ++i;
      sx += 4;
      sy += 8;
    }
    // If the shadow isn't skipped this frame, draw it
    if (shadow_type >= 2 || frame != shadow_type) {
      // Draw the actual shadow using palette 2
      unsigned int tilenum = shadow_type - (shadow_type > 0);
      tilenum = tilenum * 32 + cur_shape * 16;
      SOAM[i].attr0 = ATTR0_Y(sy) | ATTR0_4BPP | ATTR0_SQUARE;
      SOAM[i].attr1 = ATTR1_X(sx) | ATTR1_SIZE_32 | facing;
      SOAM[i].attr2 = 0x2000 + tilenum;
      ++i;
    }
    ppu_clear_oam(i);

    VBlankIntrWait();
    REG_DMA0CNT = 0;
    REG_BGCNT[0] = BG_4BPP|BG_SIZE0|BG_CBB(2)|BG_SBB(PFOVERLAY);
    REG_BG_OFS[0].x = 0;
    REG_BG_OFS[0].y = (changetimeout > 8) ? 8 : changetimeout;
    pal_bg_mem[241] = RGB5(31, 31, 31);
    pal_bg_mem[242] = RGB5(0, 0, 0);
    for (unsigned int y = 0; y < 3; ++y) {
      for (unsigned int x = 0; x < 3; ++x) {
        pal_obj_mem[y * 16 + x + 1] = shadow_sprite_palettes[y][x];
      }
    }
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_BG1 | DCNT_OBJ_1D | DCNT_OBJ;
    ppu_copy_oam();
    bgtypes[cur_bg].set_scroll(hdmaTable, x * 4);
  } while (!(new_keys & KEY_B));

  // clean up after hill zone
  REG_DMA0CNT = 0;
}
