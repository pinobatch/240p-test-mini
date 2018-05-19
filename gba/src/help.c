#include <gba_video.h>
#include <gba_compression.h>
#include <gba_dma.h>
#include <gba_input.h>
#include "global.h"

// Code units
#define LF 0x0A
#define GL_RIGHT 0x84
#define GL_LEFT 0x85
#define GL_UP 0x86
#define GL_DOWN 0x87

#define WINDOW_WIDTH 16  // Width of window in tiles not including left border
#define BACK_WALL_HT 14  // Height of back wall in tiles
#define BGMAP 29
#define FGMAP 30
#define BLANKMAP 31  // This map is kept blank to suppress text background wrapping
#define SHADOW_X 2
#define SHADOW_Y 17

#define TILE_BACK_WALL 272
#define TILE_FG_BLANK 273
#define TILE_BACK_WALL_BOTTOM 274
#define TILE_FG_CORNER1 275
#define TILE_FLOOR 276
#define TILE_FG_DIVIDER 277
#define TILE_FLOOR_TOP 278
#define TILE_FG_CORNER2 279
#define TILE_FLOOR_SHADOW 280

#define CHARACTER_VRAM_BASE 956

unsigned char help_line_buffer[HELP_LINE_LEN];
unsigned char help_bg_loaded = 0;
unsigned char help_wanted_page = 0;
unsigned char help_cur_page = (unsigned char)-1;
unsigned char help_cursor_y = 0;

/* VRAM map

If anything clobbers data described here, it needs to clear
help_bg_loaded.

BG VRAM
C0-E1 (PT3#000-10F): VWF canvas (16 by 17 tiles)
E2-E3 (110-11F): background tiles
E8-EF (NT29): BG1 (back wall)
F0-F7 (NT30): BG0 (VWF text)
F8-FF (NT31): Blank so that 

Sprite VRAM
956-1019: Gus
1020: Arrow

*/

extern const unsigned int helpbgtiles_chrTiles[];
extern const unsigned short helpbgtiles_chrPal[16];
extern const unsigned char helpsprites_chrTiles[];
extern const unsigned short helpsprites_chrPal[16];

void load_help_bg(void) {

  // Load pattern table
  LZ77UnCompVram(helpbgtiles_chrTiles, PATRAM4(3, 272));
  LZ77UnCompVram(helpsprites_chrTiles, SPR_VRAM(CHARACTER_VRAM_BASE));

  // Clear VWF canvas
  dma_memset16(PATRAM4(3, 0), 0x0000, 32*16*17);

  // Load background nametable
  dma_memset16(MAP[BGMAP][0], TILE_BACK_WALL, 64*(BACK_WALL_HT - 1));
  dma_memset16(MAP[BGMAP][BACK_WALL_HT - 1], TILE_BACK_WALL_BOTTOM, 30*2);
  dma_memset16(MAP[BGMAP][BACK_WALL_HT], TILE_FLOOR_TOP, 30*2);
  dma_memset16(MAP[BGMAP][BACK_WALL_HT + 1], TILE_FLOOR, 64*(19 - BACK_WALL_HT));
  for (unsigned int x = 0; x < 4; ++x) {
    // ccccvhtt tttttttt
    MAP[BGMAP][SHADOW_Y][SHADOW_X + x] = TILE_FLOOR_SHADOW + x;
    MAP[BGMAP][SHADOW_Y][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0403 - x;
    MAP[BGMAP][SHADOW_Y + 1][SHADOW_X + x] = TILE_FLOOR_SHADOW + 0x0800 + x;
    MAP[BGMAP][SHADOW_Y + 1][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0C03 - x;
  }

  // Load window nametable
  MAP[FGMAP][0][0] = MAP[FGMAP][20][0] = 280;
  MAP[FGMAP][0][0] = MAP[FGMAP][19][0] = 281;

  help_bg_loaded = 1;
}

static void draw_character() {
  unsigned int ou = oam_used;
  for (unsigned int i = 0; i < 2; ++i) {
    unsigned int a0 = (18 + i * 64) | OBJ_16_COLOR | ATTR0_TALL;
    unsigned int a1 = 16 | ATTR1_SIZE_64;
    unsigned int a2 = (CHARACTER_VRAM_BASE + 32 * i) | ATTR2_PALETTE(0);

    SOAM[ou].attr0 = a0;
    SOAM[ou].attr1 = a1 | OBJ_HFLIP;
    SOAM[ou].attr2 = a2;
    ++ou;
    SOAM[ou].attr0 = a0;
    SOAM[ou].attr1 = a1 + 32;
    SOAM[ou].attr2 = a2;
    ++ou;
  }
  oam_used = ou;
}

void helpscreen(unsigned int doc_num, unsigned int keymask) {
  unsigned int new_keys;

  REG_DISPCNT = LCDC_OFF;
  if (!help_bg_loaded) {
    load_help_bg();
    REG_DISPCNT = 0;
  }
  // Load palette
  VBlankIntrWait();
  dmaCopy(helpbgtiles_chrPal, BG_COLORS+0x00, sizeof(helpbgtiles_chrPal));
  dmaCopy(helpsprites_chrPal, OBJ_COLORS+0x00, sizeof(helpsprites_chrPal));

  // Set up background regs (except DISPCNT)
  BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(3)|SCREEN_BASE(BGMAP);
  BGCTRL[0] = BG_16_COLOR|BG_WID_64|BG_HT_32|CHAR_BASE(3)|SCREEN_BASE(FGMAP);
  BG_OFFSET[1].x = BG_OFFSET[1].y = 0;
  BG_OFFSET[0].x = 512-228;
  BG_OFFSET[0].y = 4;

  // Freeze
  do {
    scanKeys();
    new_keys = keysDown();

//    move_player();

    oam_used = 0;
    draw_character();
    ppu_clear_oam(oam_used);
    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG1_ON | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    ppu_copy_oam();
  } while (!(new_keys & KEY_B));
}
