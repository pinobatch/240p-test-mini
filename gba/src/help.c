/*
Help viewer for 160p Test Suite
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
#include "posprintf.h"
#include "helpsprites_chr.h"
#include "helpbgtiles_chr.h"

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
#define WXBASE ((512 - 240) + (16 + 8 * WINDOW_WIDTH))

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
#define ARROW_TILE 1020
#define BLINK_TILE 1021

#define FG_BGCOLOR 6
#define FG_FGCOLOR 2

char help_line_buffer[HELP_LINE_LEN] __attribute__((aligned (2)));
unsigned char help_cur_page = (unsigned char)-1;
unsigned char help_bg_loaded;
unsigned char help_wanted_page;
unsigned char help_cursor_y;
unsigned char help_height;
unsigned char blink_time;
// Set this to 0 for no cursor and no indent or the indent depth
// for cursor and indent
unsigned char help_show_cursor;
signed char help_wnd_progress;


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

static void load_help_bg(void) {

  // Load pattern table
  LZ77UnCompVram(helpbgtiles_chrTiles, tile_mem[3][272].data);
  LZ77UnCompVram(helpsprites_chrTiles, tile_mem_obj[0][CHARACTER_VRAM_BASE].data);

  // Clear VWF canvas
  memset16(tile_mem[3][0].data, 0x1111 * FG_BGCOLOR, 16*WINDOW_WIDTH*17);

  // Load background SCREENMAT
  memset16(se_mat[BGMAP][0], TILE_BACK_WALL, 32*(BACK_WALL_HT - 1));
  memset16(se_mat[BGMAP][BACK_WALL_HT - 1], TILE_BACK_WALL_BOTTOM, 30);
  memset16(se_mat[BGMAP][BACK_WALL_HT], TILE_FLOOR_TOP, 30);
  memset16(se_mat[BGMAP][BACK_WALL_HT + 1], TILE_FLOOR, 32*(19 - BACK_WALL_HT));
  for (unsigned int x = 0; x < 4; ++x) {
    // ccccvhtt tttttttt
    se_mat[BGMAP][SHADOW_Y][SHADOW_X + x] = TILE_FLOOR_SHADOW + x;
    se_mat[BGMAP][SHADOW_Y][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0403 - x;
    se_mat[BGMAP][SHADOW_Y + 1][SHADOW_X + x] = TILE_FLOOR_SHADOW + 0x0800 + x;
    se_mat[BGMAP][SHADOW_Y + 1][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0C03 - x;
  }
  
  // Clear window SCREENMAT
  memset16(se_mat[FGMAP], TILE_FG_BLANK, 32*21);
  memset16(se_mat[FGMAP + 1], TILE_FG_XPARENT, 32*21);

  // Left border
  se_mat[FGMAP][0][0] = TILE_FG_CORNER1;
  se_mat[FGMAP][1][0] = TILE_FG_CORNER2;
  for (unsigned int i = 2; i < 19; ++i) {
    se_mat[FGMAP][i][0] = TILE_FG_LEFT;
  }
  se_mat[FGMAP][19][0] = TILE_FG_CORNER2 + 0x0800;
  se_mat[FGMAP][20][0] = TILE_FG_CORNER1 + 0x0800;

  // Divider lines
  memset16(&(se_mat[FGMAP][2][1]), TILE_FG_DIVIDER, 16);
  memset16(&(se_mat[FGMAP][18][1]), TILE_FG_DIVIDER, 16);
  
  // Make the frame
  loadMapRowMajor(&(se_mat[FGMAP][1][1]), 0*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);
  loadMapRowMajor(&(se_mat[FGMAP][3][1]), 1*WINDOW_WIDTH,
                  WINDOW_WIDTH, PAGE_MAX_LINES);
  loadMapRowMajor(&(se_mat[FGMAP][4+PAGE_MAX_LINES][1]), (PAGE_MAX_LINES + 1)*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);

  help_bg_loaded = 1;
  help_height = 0;
  help_cur_page = -1;  // Request the wanted page
  help_wnd_progress = 0;  // Schedule inward transition
}

static void help_draw_character(void) {
  unsigned int ou = oam_used;
  
  if (++blink_time < 8) {
    SOAM[ou].attr0 = 49 | ATTR0_4BPP | ATTR0_SQUARE;
    SOAM[ou].attr1 = 48 | ATTR1_SIZE_8;
    SOAM[ou].attr2 = BLINK_TILE | ATTR2_PALBANK(0);
    ++ou;
    SOAM[ou].attr0 = 49 | ATTR0_4BPP | ATTR0_SQUARE;
    SOAM[ou].attr1 = 40 | ATTR1_SIZE_8 | ATTR1_HFLIP;
    SOAM[ou].attr2 = BLINK_TILE | ATTR2_PALBANK(0);
    ++ou;
  }
  for (unsigned int i = 0; i < 2; ++i) {
    unsigned int a0 = (18 + i * 64) | ATTR0_4BPP | ATTR0_TALL;
    unsigned int a1 = 16 | ATTR1_SIZE_64;
    unsigned int a2 = (CHARACTER_VRAM_BASE + 32 * i) | ATTR2_PALBANK(0);

    SOAM[ou].attr0 = a0;
    SOAM[ou].attr1 = a1 | ATTR1_HFLIP;
    SOAM[ou].attr2 = a2;
    ++ou;
    SOAM[ou].attr0 = a0;
    SOAM[ou].attr1 = a1 + 32;
    SOAM[ou].attr2 = a2;
    ++ou;
  }
  oam_used = ou;
}

static void help_draw_cursor(unsigned int objx) {
  if (objx >= 240) return;

  unsigned int ou = oam_used;
  SOAM[ou].attr0 = (20 + help_cursor_y * 8) | ATTR0_4BPP | ATTR0_SQUARE;
  SOAM[ou].attr1 = objx | ATTR1_SIZE_8;
  SOAM[ou].attr2 = ARROW_TILE | ATTR2_PALBANK(0);
  oam_used = ou + 1;
}

static void help_draw_page(helpdoc_kind doc_num, unsigned int left, unsigned int keymask) {
  // Draw document title
  memset16(tile_mem[3][0].data, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
  vwf8Puts(tile_mem[3][0].data, helptitles[doc_num], 0, FG_FGCOLOR);

  // Look up the address of the start of this page's text
  help_cur_page = help_wanted_page;
  const char *src = helppages[help_wanted_page];
  unsigned int y = 0;

  // Draw lines of text to the screen
  while (y < PAGE_MAX_LINES) {
    u32 *dst = tile_mem[3][(y + 1)*WINDOW_WIDTH].data;
    ++y;
    memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
    src = vwf8Puts(dst, src, left, FG_FGCOLOR);

    // Break on NUL terminator or skip others
    if (!*src) break;
    ++src;
  }

  // Clear unused lines that had been used
  for (unsigned int clear_y = y; clear_y < help_height; ++clear_y) {
    u32 *dst = tile_mem[3][(clear_y + 1)*WINDOW_WIDTH].data;
    memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
  }

  // Save how many lines are used and move the cursor up if needed
  help_height = y;
  if (help_cursor_y >= y) {
    help_cursor_y = y - 1;
  }

  // Draw status line depending on size of document and which
  // keys are enabled
  u32 *dst = tile_mem[3][(PAGE_MAX_LINES + 1)*WINDOW_WIDTH].data;
  memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);

  if (help_cumul_pages[doc_num + 1] - help_cumul_pages[doc_num] > 1) {
    posprintf(help_line_buffer, "\x1D %d/%d \x1C",
              help_wanted_page - help_cumul_pages[doc_num] + 1, 
              help_cumul_pages[doc_num + 1] - help_cumul_pages[doc_num]);
    vwf8Puts(tile_mem[3][(PAGE_MAX_LINES + 1)*WINDOW_WIDTH].data,
             help_line_buffer, 0, FG_FGCOLOR);
  }
  if (keymask & KEY_UP) {
    vwf8Puts(tile_mem[3][(PAGE_MAX_LINES + 1)*WINDOW_WIDTH].data,
             "\x1E\x1F""A: Select", 40, FG_FGCOLOR);
  }
  if (keymask & KEY_B) {
    vwf8Puts(tile_mem[3][(PAGE_MAX_LINES + 1)*WINDOW_WIDTH].data,
             "B: Exit", WINDOW_WIDTH * 8 - 28, FG_FGCOLOR);
  }
}

static const unsigned short bg0_x_sequence[] = {
  256,
  WXBASE-130,
  WXBASE-108,
  WXBASE-88,
  WXBASE-70,
  WXBASE-54,
  WXBASE-40,
  WXBASE-28,
  WXBASE-18,
  WXBASE-10,
  WXBASE-4,
  WXBASE-0,
  WXBASE+2,
  WXBASE+3,
  WXBASE+4,
  WXBASE+3,
  WXBASE+1,
  WXBASE+0
};

#define bg0_x_sequence_last (count(bg0_x_sequence) - 1)
#define bg0_x_sequence_peak (count(bg0_x_sequence) - 4)

static unsigned int help_move_window(void) {
  // If a transition is at its peak, and another transition is
  // requested, shortcut its retraction to the locked position
  if (help_wnd_progress == bg0_x_sequence_peak
      && help_cur_page != help_wanted_page) {
    help_wnd_progress = -(signed int)bg0_x_sequence_peak;
  }

  // Clock the sequence forward one step
  if (help_wnd_progress < (signed int)bg0_x_sequence_last) {
    ++help_wnd_progress;
  }
  unsigned int x = bg0_x_sequence[help_wnd_progress < 0 ? -help_wnd_progress : help_wnd_progress];
  return x;
}

unsigned int helpscreen(helpdoc_kind doc_num, unsigned int keymask) {

  // If not within this document, move to the first page
  // and move the cursor (if any) to the top
  if (help_wanted_page < help_cumul_pages[doc_num]
      || help_wanted_page >= help_cumul_pages[doc_num + 1]) {
    help_wanted_page = help_cumul_pages[doc_num];
    help_cursor_y = 0;
  }

  // If the help VRAM needs to be reloaded, reload its tiles and map
  if (!help_bg_loaded) {
    REG_DISPCNT = DCNT_BLANK;
    load_help_bg();
    REG_DISPCNT = 0;
  } else {
    // If changing pages while BG CHR and map are loaded,
    // schedule an out-load-in sequence and hide the cursor
    if (help_cur_page != help_wanted_page) {
      if (help_wnd_progress != 0) {
        help_wnd_progress = -(signed int)bg0_x_sequence_last;
      }
      help_show_cursor = 0;
    }
  }

  // Load palette
  VBlankIntrWait();
  tonccpy(pal_bg_mem+0x00, helpbgtiles_chrPal, sizeof(helpbgtiles_chrPal));
  tonccpy(pal_obj_mem+0x00, helpsprites_chrPal, sizeof(helpsprites_chrPal));

  // Set up background regs (except DISPCNT)
  REG_BGCNT[1] = BG_4BPP|BG_WID_32|BG_HT_32|BG_CBB(3)|BG_SBB(BGMAP);
  REG_BGCNT[0] = BG_4BPP|BG_WID_64|BG_HT_32|BG_CBB(3)|BG_SBB(FGMAP);
  REG_BG_OFS[1].x = REG_BG_OFS[1].y = 0;
  REG_BG_OFS[0].x = help_wnd_progress ? WXBASE : 256;
  REG_BG_OFS[0].y = 4;
  
  // Freeze
  while (1) {
    read_pad();
    new_keys &= keymask;
    autorepeat(KEY_UP|KEY_DOWN);

    // Page to page navigation
    if ((new_keys & KEY_LEFT) 
        && (help_wanted_page > help_cumul_pages[doc_num])) {
      --help_wanted_page;
    }
    if ((new_keys & KEY_RIGHT) 
        && (help_wanted_page + 1 < help_cumul_pages[doc_num + 1])) {
      ++help_wanted_page;
    }

    // Up and down navigation based on page's line count
    if ((new_keys & KEY_UP) && (help_cursor_y > 0)) {
      --help_cursor_y;
    }
    if ((new_keys & KEY_DOWN) && (help_cursor_y + 1 < help_height)) {
      ++help_cursor_y;
    }
    
    // If an exit key is pressed while the showing page is the
    // wanted page, stop
    if (help_cur_page == help_wanted_page) {
      if (new_keys & (KEY_B | KEY_A | KEY_START)) {
        return help_cur_page - help_cumul_pages[doc_num];
      }
    } else {
      // If the showing and wanted pages differ, and a transition
      // isn't running, start one
      if (help_wnd_progress >= (signed int)bg0_x_sequence_last) {
        help_wnd_progress = -(signed int)bg0_x_sequence_last;
      }
    }

    if (help_wnd_progress == 0) {
      help_show_cursor = (keymask & KEY_UP) ? 6 : 0;
      help_draw_page(doc_num, help_show_cursor, keymask);
    }

    unsigned int wx = help_move_window();
    // If fully offscreen, decide whether to hide or show the cursor

    oam_used = 0;
    help_draw_character();
    if (help_show_cursor) help_draw_cursor(512 - wx + 6);
    ppu_clear_oam(oam_used);
    VBlankIntrWait();
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG1 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ;
    REG_BG_OFS[0].x = wx;
    ppu_copy_oam();
  }
}

/**
 * Polls the controller and displays a help document if Start
 * was pressed.
 * @param pg an extern helpsect_ value
 * @return 1 if pressed, 0 if not
 */
unsigned int read_pad_help_check(helpdoc_kind pg) {
  read_pad();
  if (!(new_keys & KEY_START)) return 0;

  REG_BLDCNT = 0;
  REG_SOUND3CNT_H = 0;
  REG_SOUND1CNT_H = 0;
  REG_SOUND1CNT_X = 0x8000;
  REG_SOUND2CNT_L = 0;
  REG_SOUND2CNT_H = 0x8000;
  REG_DMA0CNT = 0;
  REG_DMA1CNT = 0;
  REG_DMA2CNT = 0;
  REG_DMA3CNT = 0;
  help_wnd_progress = 0;
  helpscreen(pg, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
  new_keys = 0;
  help_wnd_progress = 0;
  return 1;
}
