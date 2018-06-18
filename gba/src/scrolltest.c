#include "global.h"
#include <gba_input.h>
#include <gba_video.h>
#include <gba_dma.h>

extern const unsigned char helpsect_grid_scroll_test[];
extern const unsigned char helpsect_hill_zone_scroll_test[];
extern const unsigned char helpsect_vertical_scroll_test[];

#define PFMAP 23

const unsigned int small_grid_tile[] = {
  0x11111111,
  0x10000001,
  0x10000001,
  0x10000001,
  0x10000001,
  0x10000001,
  0x10000001,
  0x11111111
};

unsigned short scrolltest_y;
unsigned char scrolltest_dy;
unsigned char scrolltest_dir;
unsigned char scrolltest_pause;

void activity_grid_scroll(void) {
  unsigned int inverted = 0;
  unsigned int held_keys = 0;
  unsigned int x = 0, y = 0;
  
  scrolltest_dir = KEY_RIGHT;
  scrolltest_pause = 0;
  scrolltest_dy = 1;

  dmaCopy(small_grid_tile, PATRAM4(0, 0), sizeof(small_grid_tile));
  dma_memset16(MAP[PFMAP], 0x0000, 32*32*2);
  while (1) {
    read_pad_help_check(helpsect_grid_scroll_test);
    held_keys |= new_keys;
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      REG_BLDCNT = 0;
      return;
    }
    if (cur_keys & KEY_A) {
      // A + direction (not diagonal): change direction
      unsigned int newdir = new_keys & (KEY_UP | KEY_DOWN | KEY_LEFT | KEY_RIGHT);
      if (newdir) {
        scrolltest_dir = newdir;
        held_keys &= ~KEY_A;
      }
    } else {
      if (held_keys & KEY_A) {
        scrolltest_pause = !scrolltest_pause;
        held_keys &= ~KEY_A;
      }
      if ((new_keys & KEY_UP) && scrolltest_dy < 4) {
        ++scrolltest_dy;
      }
      if ((new_keys & KEY_DOWN) && scrolltest_dy > 1) {
        --scrolltest_dy;
      }
    }

    if (scrolltest_pause) {
    
    } else if (scrolltest_dir & KEY_LEFT) {
      x -= scrolltest_dy;
    } else if (scrolltest_dir & KEY_RIGHT) {
      x += scrolltest_dy;
    } else if (scrolltest_dir & KEY_UP) {
      y -= scrolltest_dy;
    } else if (scrolltest_dir & KEY_DOWN) {
      y += scrolltest_dy;
    }
    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = x;
    BG_OFFSET[0].y = y;
    BG_COLORS[0] = inverted ? RGB5(31,31,31) : RGB5(0, 0, 0);
    BG_COLORS[1] = inverted ? RGB5(0, 0, 0) : RGB5(31,31,31);
    REG_DISPCNT = MODE_0 | BG0_ON;
  }
}

// Game-like scroll tests ///////////////////////////////////////////

static void move_1d_scroll(void) {
  if (new_keys & (KEY_LEFT | KEY_RIGHT)) {
    scrolltest_dir = !scrolltest_dir;
  }
  if (new_keys & KEY_A) {
    scrolltest_pause = !scrolltest_pause;
  }
  if ((new_keys & KEY_UP) && scrolltest_dy < 16) {
    ++scrolltest_dy;
  }
  if ((new_keys & KEY_DOWN) && scrolltest_dy > 1) {
    --scrolltest_dy;
  }
  if (scrolltest_pause) {
    
  } else if (scrolltest_dir) {
    scrolltest_y -= scrolltest_dy;
  } else {
    scrolltest_y += scrolltest_dy;
  }
}

static void load_kiki_bg(void) {
  
}

void activity_kiki_scroll(void) {
  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  load_kiki_bg();
  lame_boy_demo();
}

void load_hill_zone_bg(void) {
  
}

void activity_hill_zone_scroll(void) {
  scrolltest_y = scrolltest_dir = scrolltest_pause = 0;
  scrolltest_dy = 1;
  load_hill_zone_bg();
  lame_boy_demo();
}

