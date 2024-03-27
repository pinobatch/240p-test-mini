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
#define RIGHT_WALL 208
#define PFMAP 23  // maps 24-31 are reserved for help
#define OBJ_VRAM_BASE 16

static void load_player(void) {
  LZ77UnCompVram(spritegfx_chrTiles, &(tile_mem_obj[0][16].data));
  player_x = 56 << 8;
  player_dx = player_frame = player_facing = 0;
}

static void move_player(void) {
  // Acceleration and braking while moving right
  if (player_dx >= 0) {
    if (cur_keys & KEY_RIGHT) {
      player_dx += WALK_ACCEL;
      if (player_dx > WALK_SPD) player_dx = WALK_SPD;
      player_facing &= ~ATTR1_HFLIP;
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
      player_facing |= ATTR1_HFLIP;
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
  unsigned int player_y = 144;
  unsigned int tile = (player_frame >> 8) * 6 + 16;
  unsigned int player_hotspot_x = (player_x >> 8) - 8;
  if ((player_frame >> 8) == 7) {
    // Frame 1 needs to be drawn 1 pixel forward
    player_hotspot_x += (player_facing & ATTR1_HFLIP) ? -1 : 1;
  }
  unsigned int attr1 = ATTR1_X(player_hotspot_x) | player_facing;

  SOAM[i].attr0 = ATTR0_Y(player_y - 24) | ATTR0_4BPP | ATTR0_WIDE;
  SOAM[i].attr1 = attr1 | ATTR1_SIZE_8;
  SOAM[i].attr2 = tile;
  ++i;
  SOAM[i].attr0 = ATTR0_Y(player_y - 16) | ATTR0_4BPP | ATTR0_SQUARE;
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
  se_mat[PFMAP][y][x]     = 12 | 0x0000;
  se_mat[PFMAP][y][x+1]   = 13 | 0x0000;
  se_mat[PFMAP][y+1][x]   = 14 | 0x0000;
  se_mat[PFMAP][y+1][x+1] = 15 | 0x0000;
}

void load_common_bg_tiles(void) {
  bitunpack2(&(tile_mem[0][0].data), bggfx_chrTiles, sizeof(bggfx_chrTiles));
}

void load_common_obj_tiles(void) {
  bitunpack2(&(tile_mem_obj[0][0].data), bggfx_chrTiles, sizeof(bggfx_chrTiles));
}

static void draw_bg(void) {
  load_common_bg_tiles();

  // Draw background map: sky, top row of floor, bottom row of floor
  memset16(se_mat[PFMAP][0], 0x0004, 32*18);
  memset16(se_mat[PFMAP][18], 11 | 0x1000, 30);
  memset16(se_mat[PFMAP][19], 1 | 0x1000, 30);
  put1block(2, 14);
  put1block(2, 16);
  put1block(26, 14);
  put1block(26, 16);

  const char return_msg[] =
    "\x08""\x08""In March 2024,\n"
    "\x22""\x10""Pino switched to Wonderful Toolchain.";
  vwfDrawLabels(return_msg, PFMAP, 0x1000 + 32);
}

void lame_boy_demo(void) {
  // Forced blanking
  REG_DISPCNT = DCNT_BLANK;
  draw_bg();
  load_player();
  REG_DISPCNT = 0;

  // Freeze
  do {
    read_pad_help_check(helpsect_lame_boy);
    move_player();

    oam_used = 0;
    draw_player_sprite();
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ;
    REG_BGCNT[0] = BG_4BPP|BG_WID_32|BG_HT_32|BG_CBB(0)|BG_SBB(PFMAP);
    REG_BG_OFS[0].x = REG_BG_OFS[0].y = 0;
    tonccpy(pal_bg_mem+0x00, bgcolors00, sizeof(bgcolors00));
    tonccpy(pal_bg_mem+0x10, bgcolors10, sizeof(bgcolors10));
    tonccpy(pal_obj_mem+0x00, spritegfx_chrPal, sizeof(spritegfx_chrPal));
    ppu_copy_oam();
  } while (!(new_keys & KEY_B));
}
