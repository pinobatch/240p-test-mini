#include "global.h"
#include <gba_input.h>
#include <gba_video.h>
#include <gba_dma.h>
#include <gba_compression.h>

/* Shadow sprite implementation plan

Load shadow reticle and Hepsie sprites (32 tiles)
Calculate them ANDed with each shadow type (128 sprite VRAM tiles total)
Convert Gus sketch in full fidelity
Load Gus sketch

*/

extern const unsigned char helpsect_shadow_sprite[];
#define PFSCROLLTEST 22
#define PFOVERLAY 21

extern const unsigned int Gus_portrait_chrTiles[];
extern const unsigned short Gus_portrait_chrMap[20][14];
extern const unsigned short Gus_portrait_chrPal[16];

static void gus_bg_setup(void) {
  LZ77UnCompVram(Gus_portrait_chrTiles, PATRAM4(0, 0));
  dma_memset16(MAP[PFSCROLLTEST], 0x0000, 32*20*2);
  load_flat_map(&(MAP[PFSCROLLTEST][0][8]), Gus_portrait_chrMap[0], 14, 20);
}

static void gus_bg_set_scroll(unsigned int unused) {
  (void)unused;
  BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
  BG_OFFSET[1].x = 0;
  BG_OFFSET[1].y = 0;
  dmaCopy(Gus_portrait_chrPal, BG_COLORS, sizeof(Gus_portrait_chrPal));
}

static void striped_bg_setup(unsigned int tilenum) {
  load_common_bg_tiles();
  dma_memset16(MAP[PFSCROLLTEST], tilenum, 32*20*2);
}

static void bg_2_setup() {
  striped_bg_setup(0x000A);
}

static void bg_3_setup() {
  striped_bg_setup(0x0000);
}

static void striped_bg_set_scroll(unsigned int unused) {
  (void)unused;
  BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFSCROLLTEST);
  BG_OFFSET[1].x = 0;
  BG_OFFSET[1].y = 0;
  BG_COLORS[0] = BG_COLORS[2] = 0;
  BG_COLORS[3] = RGB5(31, 31, 31);
}

typedef struct ShadowSpriteBG {
  void (*setup)(void);
  void (*set_scroll)(unsigned int x);
} ShadowSpriteBG;

const ShadowSpriteBG bgtypes[4] = {
  {gus_bg_setup, gus_bg_set_scroll},
  {hill_zone_load_bg, hill_zone_set_scroll},
  {bg_2_setup, striped_bg_set_scroll},
  {bg_3_setup, striped_bg_set_scroll},
};

extern const VBTILE hepsie_chrTiles[32];

static const unsigned short shadow_sprite_palettes[3][3] = {
  {RGB5( 0, 0, 0),RGB5( 0,31, 0),RGB5(31,25,19)},  // Hepsie top half
  {RGB5( 0, 0, 0),RGB5(31, 0,31),RGB5(31,31, 0)},  // Hepsie bottom half
  {RGB5( 0, 0, 0),RGB5( 0, 0, 0),RGB5( 0, 0, 0)},  // Shadow
};

void activity_shadow_sprite() {
  unsigned int held_keys = 0, x = 112, y = 64, facing = 0;
  unsigned int cur_bg = 0, changetimeout = 0;
  unsigned int cur_shape = 0, shadow_type = 0, frame = 0;
  
  dma_memset16(MAP[PFOVERLAY], 0xF000, 32*21*2);
  loadMapRowMajor(&(MAP[PFOVERLAY][20][23]), 0xF001, 7, 1);
  dma_memset16(PATRAM4(2, 0), 0x0000, 32*1);
  dma_memset16(PATRAM4(2, 1), 0x2222, 32*7);

  bitunpack2(SPR_VRAM(0), hepsie_chrTiles, sizeof(hepsie_chrTiles));
  // TODO: Expand shadow reticle and Hepsie to four shadow types
  
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
        cur_bg = (cur_bg + 1) & 0x03;
        REG_DISPCNT = MODE_0 | BG0_ON | OBJ_ON;
        bgtypes[cur_bg].setup();
      }
      if (new_keys & KEY_LEFT) {
        cur_bg = (cur_bg - 1) & 0x03;
        REG_DISPCNT = MODE_0 | BG0_ON | OBJ_ON;
        bgtypes[cur_bg].setup();
      }
    } else {
      if ((cur_keys & KEY_RIGHT) && x < 240 - 32) {
        x += 1;
        facing = 0;
      }
      if ((cur_keys & KEY_LEFT) && x > 0) {
        x -= 1;
        facing = OBJ_HFLIP;
      }
      if ((cur_keys & KEY_DOWN) && y < 160 - 32) {
        y += 1;
      }
      if ((cur_keys & KEY_UP) && y > 0) {
        y -= 1;
      }
    }

    unsigned int i = 0, sx = x, sy = y;
    if (cur_shape) {  // Draw the nontransparent part of Hepsie
      SOAM[i].attr0 = OBJ_Y(y) | OBJ_16_COLOR | ATTR0_WIDE;
      SOAM[i].attr1 = OBJ_X(x - 4) | ATTR1_SIZE_32 | facing;
      SOAM[i].attr2 = 0x0010;
      ++i;
      SOAM[i].attr0 = OBJ_Y(y + 16) | OBJ_16_COLOR | ATTR0_WIDE;
      SOAM[i].attr1 = OBJ_X(x - 4) | ATTR1_SIZE_32 | facing;
      SOAM[i].attr2 = 0x1018;
      ++i;
      sx += 4;
      sy += 8;
    }
    // TODO: Draw sprite based on x, y, cur_shape, shadow_type, frame, and facing
    ppu_clear_oam(i);

    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(2)|SCREEN_BASE(PFOVERLAY);
    BG_OFFSET[0].x = 0;
    BG_OFFSET[0].y = (changetimeout > 8) ? 8 : changetimeout;
    BG_COLORS[241] = RGB5(31, 31, 31);
    BG_COLORS[242] = RGB5(0, 0, 0);
    for (unsigned int y = 0; y < 3; ++y) {
      for (unsigned int x = 0; x < 3; ++x) {
        OBJ_COLORS[y * 16 + x + 1] = shadow_sprite_palettes[y][x];
      }
    }
    REG_DISPCNT = MODE_0 | BG0_ON | BG1_ON | OBJ_1D_MAP | OBJ_ON;
    ppu_copy_oam();
    bgtypes[cur_bg].set_scroll(x * 4);
  } while (!(new_keys & KEY_B));
}
