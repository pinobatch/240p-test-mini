/*
"Lame boy" demo for Game Boy Advance
Copyright 2018 Damian Yerrick

This work is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any
damages arising from the use of this work.

Permission is granted to anyone to use this work for any purpose,
including commercial applications, and to alter it and redistribute
it freely, subject to the following restrictions:

1. The origin of this work must not be misrepresented; you must
   not claim that you wrote the original work. If you use
   this work in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original work.
3. This notice may not be removed or altered from any source
   distribution.

"Source" is the preferred form of a work for making changes to it.

*/
#include <string.h>
#include "global.h"

#include "bggfx_chr.h"
#include "spritegfx_chr.h"

unsigned short player_x;
signed short player_dx;
unsigned short player_frame;
unsigned short player_facing = 0;

#define WALK_SPD 105
#define WALK_ACCEL 4
#define WALK_BRAKE 8
#define LEFT_WALL 32
#define RIGHT_WALL (SCREEN_WIDTH - 32)
#define PFMAP 23  // maps 24-31 are reserved for help
#define OBJ_VRAM_BASE 16

static void load_player(void) {
  LZ77UnCompVram(spritegfx_chrTiles, SPR_VRAM(OBJ_VRAM_BASE));
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  LZ77UnCompVram(spritegfx_chrTiles, SPR_VRAM_SUB(OBJ_VRAM_BASE));
  #endif
  player_x = 56 << 8;
  player_dx = player_frame = player_facing = 0;
}

static void move_player(void) {
  // Acceleration and braking while moving right
  if (player_dx >= 0) {
    if (cur_keys & KEY_RIGHT) {
      player_dx += WALK_ACCEL;
      if (player_dx > WALK_SPD) player_dx = WALK_SPD;
      player_facing &= ~ATTR1_FLIP_X;
    } else {
      player_dx -= WALK_BRAKE;
      if (player_dx < 0) player_dx = 0;
    }
  }
  
  // Acceleration and braking while moving left
  if (player_dx <= 0) {
    if (cur_keys & KEY_LEFT) {
      player_dx -= WALK_ACCEL;
      if (player_dx < -WALK_SPD) player_dx = -WALK_SPD;
      player_facing |= ATTR1_FLIP_X;
    } else {
      player_dx += WALK_BRAKE;
      if (player_dx > 0) player_dx = 0;
    }
  }

  // In a real game you'd respond to A, B, Up, Down, etc. here
  player_x += player_dx;
  
  // Test for collision with side walls
  if (player_x < (LEFT_WALL + 4) << 8) {
    player_x = (LEFT_WALL + 4) << 8;
    player_dx = 0;
  } else if (player_x >= (RIGHT_WALL - 4) << 8) {
    player_x = (RIGHT_WALL - 5) << 8;
    player_dx = 0;
  }
  
  // Animate the player
  if (player_dx == 0) {
    player_frame = 0xC0;
  } else {
    unsigned int absspeed = (player_dx < 0) ? -player_dx : player_dx;
    player_frame += absspeed * 5 / 16;

    // Wrap from end of walk cycle (7) to start of walk cycle (1)
    if (player_frame >= 0x800) player_frame -= 0x700;
  }
}

static void draw_player_sprite(void) {
  unsigned int i = oam_used;
  unsigned int player_y = SCREEN_HEIGHT - 16;
  unsigned int tile = (player_frame >> 8) * 6 + 16;
  unsigned int player_hotspot_x = (player_x >> 8) - 8;
  if ((player_frame >> 8) == 7) {
    // Frame 1 needs to be drawn 1 pixel forward
    player_hotspot_x += (player_facing & ATTR1_FLIP_X) ? -1 : 1;
  }
  unsigned int attr1 = OBJ_X(player_hotspot_x) | player_facing;

  SOAM[i].attr0 = OBJ_Y(player_y - 24) | ATTR0_COLOR_16 | ATTR0_WIDE;
  SOAM[i].attr1 = attr1 | ATTR1_SIZE_8;
  SOAM[i].attr2 = tile;
  ++i;
  SOAM[i].attr0 = OBJ_Y(player_y - 16) | ATTR0_COLOR_16 | ATTR0_SQUARE;
  SOAM[i].attr1 = attr1 | ATTR1_SIZE_16;
  SOAM[i].attr2 = tile + 2;
  ++i;
  oam_used = i;
}

// Still trying to see whether GritHub will cause me to not need
// pilbmp2nes.py. <https://github.com/devkitPro/grit>
// It's in Virtual Boy format because that decompresses easily

static const unsigned short bgcolors00[16] = {
  RGB5(25,25,31), RGB5(20,20, 0), RGB5(27,27, 0), RGB5(31,31, 0)
};
static const unsigned short bgcolors10[16] = {
  0xFFFF, RGB5(20, 15, 0), RGB5(20,25, 0), RGB5(20,31, 0)
};

static void put1block(unsigned int x, unsigned int y) {
  MAP[PFMAP][y][x]     = 12 | 0x0000;
  MAP[PFMAP][y][x+1]   = 13 | 0x0000;
  MAP[PFMAP][y+1][x]   = 14 | 0x0000;
  MAP[PFMAP][y+1][x+1] = 15 | 0x0000;
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  MAP_SUB[PFMAP][y][x]     = 12 | 0x0000;
  MAP_SUB[PFMAP][y][x+1]   = 13 | 0x0000;
  MAP_SUB[PFMAP][y+1][x]   = 14 | 0x0000;
  MAP_SUB[PFMAP][y+1][x+1] = 15 | 0x0000;
  #endif
}

void load_common_bg_tiles(void) {
  bitunpack2(PATRAM4(0, 0), bggfx_chrTiles, sizeof(bggfx_chrTiles));
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  bitunpack2(PATRAM4_SUB(0, 0), bggfx_chrTiles, sizeof(bggfx_chrTiles));
  #endif
}

void load_common_obj_tiles(void) {
  bitunpack2(SPR_VRAM(0), bggfx_chrTiles, sizeof(bggfx_chrTiles));
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  bitunpack2(SPR_VRAM_SUB(0), bggfx_chrTiles, sizeof(bggfx_chrTiles));
  #endif
}

static void draw_bg(void) {
  load_common_bg_tiles();

  // Draw background map: sky, top row of floor, bottom row of floor
  dma_memset16(MAP[PFMAP][0], 0x0004, 2*32*((SCREEN_HEIGHT >> 3) - 2));
  dma_memset16(MAP[PFMAP][(SCREEN_HEIGHT >> 3) - 2], 11 | 0x1000, 2*(SCREEN_WIDTH >> 3));
  dma_memset16(MAP[PFMAP][(SCREEN_HEIGHT >> 3) - 1], 1 | 0x1000, 2*(SCREEN_WIDTH >> 3));
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  dma_memset16(MAP_SUB[PFMAP][0], 0x0004, 2*32*((SCREEN_HEIGHT >> 3) - 2));
  dma_memset16(MAP_SUB[PFMAP][(SCREEN_HEIGHT >> 3) - 2], 11 | 0x1000, 2*(SCREEN_WIDTH >> 3));
  dma_memset16(MAP_SUB[PFMAP][(SCREEN_HEIGHT >> 3) - 1], 1 | 0x1000, 2*(SCREEN_WIDTH >> 3));
  #endif
  put1block(2, (SCREEN_HEIGHT >> 3) - 6);
  put1block(2, (SCREEN_HEIGHT >> 3) - 4);
  put1block((SCREEN_WIDTH >> 3) - 4, (SCREEN_HEIGHT >> 3) - 6);
  put1block((SCREEN_WIDTH >> 3) - 4, (SCREEN_HEIGHT >> 3) - 4);

  // sorry I was gone
  const char return_msg_positions[] = {
    0x08, 0x08,
    0x22, 0x10
  };
  const char return_msg_labels[] =
    "In May 2018,\n"
    "Pino returned to the GBA scene.";

  vwfDrawLabelsPositionBased(return_msg_labels, return_msg_positions, PFMAP, 0x1000 + 32);
}

void lame_boy_demo() {
  // Forced blanking
  REG_DISPCNT = LCDC_OFF | ACTIVATE_SCREEN_HW;
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  REG_DISPCNT_SUB = LCDC_OFF | ACTIVATE_SCREEN_HW;
  #endif
  draw_bg();
  load_player();
  REG_DISPCNT = ACTIVATE_SCREEN_HW;
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  REG_DISPCNT_SUB = ACTIVATE_SCREEN_HW;
  #endif

  // Freeze
  do {
    read_pad_help_check(helpsect_lame_boy);
    move_player();

    oam_used = 0;
    draw_player_sprite();
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    dmaCopy(bgcolors00, BG_PALETTE+0x00, sizeof(bgcolors00));
    dmaCopy(bgcolors10, BG_PALETTE+0x10, sizeof(bgcolors10));
    dmaCopy(spritegfx_chrPal, SPRITE_PALETTE+0x00, sizeof(spritegfx_chrPal));
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    BGCTRL_SUB[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET_SUB[0].x = BG_OFFSET_SUB[0].y = 0;
    dmaCopy(bgcolors00, BG_PALETTE_SUB+0x00, sizeof(bgcolors00));
    dmaCopy(bgcolors10, BG_PALETTE_SUB+0x10, sizeof(bgcolors10));
    dmaCopy(spritegfx_chrPal, SPRITE_PALETTE_SUB+0x00, sizeof(spritegfx_chrPal));
    #endif
    ppu_copy_oam();
  } while (!(new_keys & KEY_B));
}
