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
#define PAGE_MAX_USABLE_LINES 17  // max usable lines of text in one page
#define PAGE_MAX_LINES ((SCREEN_HEIGHT >> 3) - 5)  // max lines of text in one page
#define PAGE_FINAL_MAX_LINES ((PAGE_MAX_USABLE_LINES > PAGE_MAX_LINES) ? PAGE_MAX_LINES : PAGE_MAX_USABLE_LINES)
#define BACK_WALL_HT 14  // Height of back wall in tiles
#define BGMAP 29
#define FGMAP 30
#define BLANKMAP 31  // This map is kept blank to suppress text background wrapping
#define SHADOW_X 2
#define SHADOW_Y 17
#define WXBASE ((512 - SCREEN_WIDTH) + (16 + 8 * WINDOW_WIDTH))

#define TILE_DECOMPRESSED_BASE 304

#define TILE_BACK_WALL TILE_DECOMPRESSED_BASE
#define TILE_FG_XPARENT TILE_DECOMPRESSED_BASE
#define TILE_FG_BLANK (TILE_DECOMPRESSED_BASE + 1)
#define TILE_BACK_WALL_BOTTOM (TILE_DECOMPRESSED_BASE + 2)
#define TILE_FG_CORNER1 (TILE_DECOMPRESSED_BASE + 3)
#define TILE_FLOOR (TILE_DECOMPRESSED_BASE + 4)
#define TILE_FG_DIVIDER (TILE_DECOMPRESSED_BASE + 5)
#define TILE_FLOOR_TOP (TILE_DECOMPRESSED_BASE + 6)
#define TILE_FG_CORNER2 (TILE_DECOMPRESSED_BASE + 7)
#define TILE_FG_LEFT (TILE_DECOMPRESSED_BASE + 11)
#define TILE_FLOOR_SHADOW (TILE_DECOMPRESSED_BASE + 12)

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

static void load_bg_to_map(SCREENMAT *map_addr) {
  // Load background nametable
  memset16(map_addr[BGMAP][0], TILE_BACK_WALL, 32*(BACK_WALL_HT - 1));
  memset16(map_addr[BGMAP][BACK_WALL_HT - 1], TILE_BACK_WALL_BOTTOM, SCREEN_WIDTH >> 3);
  memset16(map_addr[BGMAP][BACK_WALL_HT], TILE_FLOOR_TOP, SCREEN_WIDTH >> 3);
  memset16(map_addr[BGMAP][BACK_WALL_HT + 1], TILE_FLOOR, 32*((SCREEN_HEIGHT >> 3) - 1 - BACK_WALL_HT));
  for (unsigned int x = 0; x < 4; ++x) {
    // ccccvhtt tttttttt
    map_addr[BGMAP][SHADOW_Y][SHADOW_X + x] = TILE_FLOOR_SHADOW + x;
    map_addr[BGMAP][SHADOW_Y][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0403 - x;
    map_addr[BGMAP][SHADOW_Y + 1][SHADOW_X + x] = TILE_FLOOR_SHADOW + 0x0800 + x;
    map_addr[BGMAP][SHADOW_Y + 1][SHADOW_X + 4 + x] = TILE_FLOOR_SHADOW + 0x0C03 - x;
  }
  
  // Clear window nametable
  memset16(map_addr[FGMAP], TILE_FG_BLANK, 32*((SCREEN_HEIGHT >> 3) + 1));
  memset16(map_addr[FGMAP + 1], TILE_FG_XPARENT, 32*((SCREEN_HEIGHT >> 3) + 1));

  // Left border
  map_addr[FGMAP][0][0] = TILE_FG_CORNER1;
  map_addr[FGMAP][1][0] = TILE_FG_CORNER2;
  for (unsigned int i = 2; i < (SCREEN_HEIGHT >> 3) - 1; ++i) {
    map_addr[FGMAP][i][0] = TILE_FG_LEFT;
  }
  map_addr[FGMAP][(SCREEN_HEIGHT >> 3) - 1][0] = TILE_FG_CORNER2 + 0x0800;
  map_addr[FGMAP][SCREEN_HEIGHT >> 3][0] = TILE_FG_CORNER1 + 0x0800;

  // Divider lines
  memset16(&(map_addr[FGMAP][2][1]), TILE_FG_DIVIDER, WINDOW_WIDTH);
  memset16(&(map_addr[FGMAP][(SCREEN_HEIGHT >> 3) - 2][1]), TILE_FG_DIVIDER, WINDOW_WIDTH);
  
  // Make the frame
  loadMapRowMajor(&(map_addr[FGMAP][1][1]), 0*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);
  loadMapRowMajor(&(map_addr[FGMAP][3][1]), 1*WINDOW_WIDTH,
                  WINDOW_WIDTH, PAGE_FINAL_MAX_LINES);
  loadMapRowMajor(&(map_addr[FGMAP][4+PAGE_MAX_LINES][1]), (PAGE_MAX_USABLE_LINES + 1)*WINDOW_WIDTH,
                  WINDOW_WIDTH, 1);
}

static void load_help_bg(void) {

  // Load pattern table
  LZ77UnCompVram(helpbgtiles_chrTiles, tile_mem[3][TILE_DECOMPRESSED_BASE].data);
  LZ77UnCompVram(helpsprites_chrTiles, tile_mem_obj[0][CHARACTER_VRAM_BASE].data);

  // Clear VWF canvas
  memset16(tile_mem[3][0].data, 0x1111 * FG_BGCOLOR, 16*WINDOW_WIDTH*(PAGE_MAX_USABLE_LINES + 2));

  load_bg_to_map(se_mat);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  // Load pattern table
  LZ77UnCompVram(helpbgtiles_chrTiles, tile_mem_sub[3][TILE_DECOMPRESSED_BASE].data);
  LZ77UnCompVram(helpsprites_chrTiles, tile_mem_obj_sub[0][CHARACTER_VRAM_BASE].data);

  // Clear VWF canvas
  memset16(tile_mem_sub[3][0].data, 0x1111 * FG_BGCOLOR, 16*WINDOW_WIDTH*(PAGE_MAX_USABLE_LINES + 2));

  load_bg_to_map(se_mat_sub);
  #endif

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
  if (objx >= SCREEN_WIDTH) return;

  unsigned int ou = oam_used;
  SOAM[ou].attr0 = (20 + help_cursor_y * 8) | ATTR0_4BPP | ATTR0_SQUARE;
  SOAM[ou].attr1 = objx | ATTR1_SIZE_8;
  SOAM[ou].attr2 = ARROW_TILE | ATTR2_PALBANK(0);
  oam_used = ou + 1;
}

static int help_draw_page(helpdoc_kind doc_num, unsigned int left, unsigned int keymask, TILE* target_tile_mem) {
  // Draw document title
  memset16(target_tile_mem[0].data, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
  vwf8Puts(target_tile_mem[0].data, helptitles[doc_num], 0, FG_FGCOLOR);

  // Look up the address of the start of this page's text
  help_cur_page = help_wanted_page;
  const char *src = helppages[help_wanted_page];
  unsigned int y = 0;

  // Draw lines of text to the screen
  while (y < PAGE_FINAL_MAX_LINES) {
    u32 *dst = target_tile_mem[(y + 1)*WINDOW_WIDTH].data;
    ++y;
    memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
    src = vwf8Puts(dst, src, left, FG_FGCOLOR);

    // Break on NUL terminator or skip others
    if (!*src) break;
    ++src;
  }

  // Clear unused lines that had been used
  for (unsigned int clear_y = y; clear_y < help_height; ++clear_y) {
    u32 *dst = target_tile_mem[(clear_y + 1)*WINDOW_WIDTH].data;
    memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);
  }

  // Save how many lines are used and move the cursor up if needed
  if (help_cursor_y >= y) {
    help_cursor_y = y - 1;
  }

  // Draw status line depending on size of document and which
  // keys are enabled
  u32 *dst = target_tile_mem[(PAGE_MAX_USABLE_LINES + 1)*WINDOW_WIDTH].data;
  memset16(dst, FG_BGCOLOR*0x1111, WINDOW_WIDTH * 16);

  if (help_cumul_pages[doc_num + 1] - help_cumul_pages[doc_num] > 1) {
    posprintf(help_line_buffer, "\x1D %d/%d \x1C",
              help_wanted_page - help_cumul_pages[doc_num] + 1, 
              help_cumul_pages[doc_num + 1] - help_cumul_pages[doc_num]);
    vwf8Puts(dst, help_line_buffer, 0, FG_FGCOLOR);
  }
  if (keymask & KEY_UP) {
    vwf8Puts(dst, "\x1E\x1F""A: Select", 40, FG_FGCOLOR);
  }
  if (keymask & KEY_B) {
    vwf8Puts(dst, "B: Exit", WINDOW_WIDTH * 8 - 28, FG_FGCOLOR);
  }

  return y;
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
    REG_DISPCNT = DCNT_BLANK | ACTIVATE_SCREEN_HW;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = DCNT_BLANK | ACTIVATE_SCREEN_HW;
    #endif
    load_help_bg();
    REG_DISPCNT = ACTIVATE_SCREEN_HW;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = ACTIVATE_SCREEN_HW;
    #endif
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
  REG_BGCNT[1] = BG_4BPP|BG_SIZE0|BG_CBB(3)|BG_SBB(BGMAP);
  REG_BGCNT[0] = BG_4BPP|BG_SIZE1|BG_CBB(3)|BG_SBB(FGMAP);
  REG_BG_OFS[1].x = REG_BG_OFS[1].y = 0;
  REG_BG_OFS[0].x = help_wnd_progress ? WXBASE : 256;
  REG_BG_OFS[0].y = 4;
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  tonccpy(pal_bg_mem_sub+0x00, helpbgtiles_chrPal, sizeof(helpbgtiles_chrPal));
  tonccpy(pal_obj_mem_sub+0x00, helpsprites_chrPal, sizeof(helpsprites_chrPal));

  // Set up background regs (except DISPCNT)
  REG_BGCNT_SUB[1] = BG_4BPP|BG_SIZE0|BG_CBB(3)|BG_SBB(BGMAP);
  REG_BGCNT_SUB[0] = BG_4BPP|BG_SIZE1|BG_CBB(3)|BG_SBB(FGMAP);
  REG_BG_OFS_SUB[1].x = REG_BG_OFS_SUB[1].y = 0;
  REG_BG_OFS_SUB[0].x = help_wnd_progress ? WXBASE : 256;
  REG_BG_OFS_SUB[0].y = 4;
  #endif
  
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
      int final_y = help_draw_page(doc_num, help_show_cursor, keymask, &tile_mem[3][0]);
      #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
      help_draw_page(doc_num, help_show_cursor, keymask, &tile_mem_sub[3][0]);
      #endif
      help_height = final_y;
    }

    unsigned int wx = help_move_window();
    // If fully offscreen, decide whether to hide or show the cursor

    oam_used = 0;
    help_draw_character();
    if (help_show_cursor) help_draw_cursor(512 - wx + 6);
    ppu_clear_oam(oam_used);
    VBlankIntrWait();
    REG_DISPCNT = DCNT_MODE0 | DCNT_BG1 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_BG_OFS[0].x = wx;
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    REG_DISPCNT_SUB = DCNT_MODE0 | DCNT_BG1 | DCNT_BG0 | DCNT_OBJ_1D | DCNT_OBJ | TILE_1D_MAP | ACTIVATE_SCREEN_HW;
    REG_BG_OFS_SUB[0].x = wx;
    #endif
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
  #ifdef __NDS__
  killAllSounds();
  #else
  REG_SOUND3CNT_H = 0;
  REG_SOUND1CNT_H = 0;
  REG_SOUND1CNT_X = 0x8000;
  REG_SOUND2CNT_L = 0;
  REG_SOUND2CNT_H = 0x8000;
  #endif
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
