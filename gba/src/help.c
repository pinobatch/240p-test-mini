#include <gba_video.h>
#include <gba_compression.h>
#include <gba_dma.h>
#include <gba_input.h>
#include "global.h"
#include "posprintf.h"

// Code units
#define LF 0x0A
#define GL_RIGHT 0x84
#define GL_LEFT 0x85
#define GL_UP 0x86
#define GL_DOWN 0x87

#define WINDOW_WIDTH 16  // Width of window in tiles not including left border
#define PAGE_MAX_LINES 15  // max lines of text in one page
#define BACK_WALL_HT 14  // Height of back wall in tiles
#define BGMAP 29
#define FGMAP 30
#define BLANKMAP 31  // This map is kept blank to suppress text background wrapping
#define SHADOW_X 2
#define SHADOW_Y 17

#define TILE_BACK_WALL 272
#define TILE_FG_XPARENT 272
#define TILE_FG_BLANK 273
#define TILE_BACK_WALL_BOTTOM 274
#define TILE_FG_CORNER1 275
#define TILE_FLOOR 276
#define TILE_FG_DIVIDER 277
#define TILE_FLOOR_TOP 278
#define TILE_FG_CORNER2 279
#define TILE_FG_LEFT 283
#define TILE_FLOOR_SHADOW 284

#define CHARACTER_VRAM_BASE 956

#define FG_BGCOLOR 6
#define FG_FGCOLOR 2

char help_line_buffer[HELP_LINE_LEN];
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
F8-FF (NT31): Blank to prevent scroll wrapping

Sprite VRAM
956-1019: Gus
1020: Arrow

The window

*/

extern const unsigned int helpbgtiles_chrTiles[];
extern const unsigned short helpbgtiles_chrPal[16];
extern const unsigned char helpsprites_chrTiles[];
extern const unsigned short helpsprites_chrPal[16];

extern const char *const helppages[];
extern const char *const helptitles[];
extern const unsigned char help_cumul_pages[];
extern const void *HELP_NUM_PAGES;
extern const void *HELP_NUM_SECTS;

void load_help_bg(void) {

  // Load pattern table
  LZ77UnCompVram(helpbgtiles_chrTiles, PATRAM4(3, 272));
  LZ77UnCompVram(helpsprites_chrTiles, SPR_VRAM(CHARACTER_VRAM_BASE));

  // Clear VWF canvas
  dma_memset16(PATRAM4(3, 0), 0x1111 * FG_BGCOLOR, 32*WINDOW_WIDTH*17);

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

  // Clear window nametable
  dma_memset16(MAP[FGMAP], TILE_FG_BLANK, 32*21*2);
  dma_memset16(MAP[FGMAP + 1], TILE_FG_XPARENT, 32*21*2);

  // Left border
  MAP[FGMAP][0][0] = TILE_FG_CORNER1;
  MAP[FGMAP][1][0] = TILE_FG_CORNER2;
  for (unsigned int i = 2; i < 19; ++i) {
    MAP[FGMAP][i][0] = TILE_FG_LEFT;
  }
  MAP[FGMAP][19][0] = TILE_FG_CORNER2 + 0x0800;
  MAP[FGMAP][20][0] = TILE_FG_CORNER1 + 0x0800;

  // Divider lines
  dma_memset16(&(MAP[FGMAP][2][1]), TILE_FG_DIVIDER, 16*2);
  dma_memset16(&(MAP[FGMAP][18][1]), TILE_FG_DIVIDER, 16*2);
  
  // Make the frame
  loadMapRowMajor(&(MAP[FGMAP][1][1]), 0*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);
  loadMapRowMajor(&(MAP[FGMAP][3][1]), 1*WINDOW_WIDTH,
                  WINDOW_WIDTH, PAGE_MAX_LINES);
  loadMapRowMajor(&(MAP[FGMAP][4+PAGE_MAX_LINES][1]), (PAGE_MAX_LINES + 1)*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);

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

  // Prove that the tile was loaded
  vwf8Puts(PATRAM4(3, 0*WINDOW_WIDTH), helptitles[0], 0, FG_FGCOLOR);
  posprintf(help_line_buffer, "\x85 %d/%d \x84  \x87\x86""A: Select  B: Exit",
            help_wanted_page - help_cumul_pages[doc_num] + 1, 
            help_cumul_pages[doc_num + 1] - help_cumul_pages[doc_num]);
  vwf8Puts(PATRAM4(3, (PAGE_MAX_LINES + 1)*WINDOW_WIDTH),
           help_line_buffer, 0, FG_FGCOLOR);

  // Load palette
  VBlankIntrWait();
  dmaCopy(helpbgtiles_chrPal, BG_COLORS+0x00, sizeof(helpbgtiles_chrPal));
  dmaCopy(helpsprites_chrPal, OBJ_COLORS+0x00, sizeof(helpsprites_chrPal));

  // Set up background regs (except DISPCNT)
  BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(3)|SCREEN_BASE(BGMAP);
  BGCTRL[0] = BG_16_COLOR|BG_WID_64|BG_HT_32|CHAR_BASE(3)|SCREEN_BASE(FGMAP);
  BG_OFFSET[1].x = BG_OFFSET[1].y = 0;
  BG_OFFSET[0].x = (512 - 240) + (16 + 8 * WINDOW_WIDTH);
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
