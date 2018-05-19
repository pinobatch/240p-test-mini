#include <gba_video.h>
#include <gba_input.h>
#include <gba_compression.h>
#include <gba_dma.h>
#include <string.h>
#include "global.h"


extern const unsigned char spritegfx_chrTiles[];
extern const unsigned short spritegfx_chrPal[16];

unsigned short player_x;
signed short player_dx;
unsigned short player_frame;
unsigned short player_facing = 0;

#define WALK_SPD 105
#define WALK_ACCEL 4
#define WALK_BRAKE 8
#define LEFT_WALL 32
#define RIGHT_WALL 208

static void load_player(void) {
  LZ77UnCompVram(spritegfx_chrTiles, SPR_VRAM(16));
  dmaCopy(spritegfx_chrPal, OBJ_COLORS+0x00, sizeof(spritegfx_chrPal));
  player_x = 56 << 8;
  player_dx = player_frame = player_facing = 0;
}

static void move_player(void) {
  unsigned int cur_keys = keysHeld();

  // Acceleration and braking while moving right
  if (player_dx >= 0) {
    if (cur_keys & KEY_RIGHT) {
      player_dx += WALK_ACCEL;
      if (player_dx > WALK_SPD) player_dx = WALK_SPD;
      player_facing &= ~OBJ_HFLIP;
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
      player_facing |= OBJ_HFLIP;
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
    player_hotspot_x += (player_facing & OBJ_HFLIP) ? -1 : 1;
  }
  unsigned int attr1 = OBJ_X(player_hotspot_x) | player_facing;

  SOAM[i].attr0 = OBJ_Y(player_y - 24) | OBJ_16_COLOR | ATTR0_WIDE;
  SOAM[i].attr1 = attr1 | ATTR1_SIZE_8;
  SOAM[i].attr2 = tile;
  ++i;
  SOAM[i].attr0 = OBJ_Y(player_y - 16) | OBJ_16_COLOR | ATTR0_SQUARE;
  SOAM[i].attr1 = attr1 | ATTR1_SIZE_16;
  SOAM[i].attr2 = tile + 2;
  ++i;
  oam_used = i;
}

// Still trying to see whether GritHub will cause me to not need
// pilbmp2nes.py. <https://github.com/devkitPro/grit>
// It's in Virtual Boy format because that decompresses easily
extern const VBTILE bggfx_chrTiles[32];

static const unsigned short bgcolors00[16] = {
  RGB5(25,25,31), RGB5(20,20, 0), RGB5(27,27, 0), RGB5(31,31, 0)
};
static const unsigned short bgcolors10[16] = {
  0xFFFF, RGB5(20, 15, 0), RGB5(20,25, 0), RGB5(20,31, 0)
};

static void put1block(unsigned int x, unsigned int y) {
  MAP[30][y][x]     = 12 | 0x0000;
  MAP[30][y][x+1]   = 13 | 0x0000;
  MAP[30][y+1][x]   = 14 | 0x0000;
  MAP[30][y+1][x+1] = 15 | 0x0000;
}

static void draw_bg(void) {
  // Load tiles
  BUP bgtilespec = {
    .SrcNum=sizeof(bggfx_chrTiles), .SrcBitNum=2, .DestBitNum=4, 
    .DestOffset=0, .DestOffset0_On=0
  };
  BitUnPack(bggfx_chrTiles, PATRAM4(0, 0), &bgtilespec);

  // Draw background map: sky, top row of floor, bottom row of floor
  dma_memset16(MAP[30][0], 0x0000, 2*32*18);
  dma_memset16(MAP[30][18], 11 | 0x1000, 2*30);
  dma_memset16(MAP[30][19], 1 | 0x1000, 2*30);
  put1block(2, 14);
  put1block(2, 16);
  put1block(26, 14);
  put1block(26, 16);
  
  // sorry I was gone
  loadMapRowMajor(&(MAP[30][1][1]), 0x1000 | 32, 28, 1);
  dma_memset16(PATRAM4(0, 32), 0x0000, 32*28);
  vwf8Puts(PATRAM4(0, 32), "In May 2018, Pino returned to the GBA scene.", 0, 1);

  // Load palette
  dmaCopy(bgcolors00, BG_COLORS+0x00, sizeof(bgcolors00));
  dmaCopy(bgcolors10, BG_COLORS+0x10, sizeof(bgcolors10));

  // Set up background regs (except DISPCNT)
  BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(30);
  BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
}

void lame_boy_demo() {
  // Forced blanking
  REG_DISPCNT = LCDC_OFF;
  draw_bg();
  load_player();
  REG_DISPCNT = 0;

  // Freeze
  do {
    scanKeys();
    move_player();

    oam_used = 0;
    draw_player_sprite();
    ppu_clear_oam(oam_used);
    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    ppu_copy_oam();
  } while (!(keysHeld() & KEY_B));
}
