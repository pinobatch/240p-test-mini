#include <gba_input.h>
#include <gba_video.h>
#include <gba_dma.h>
#include <gba_compression.h>
#include <gba_systemcalls.h>
#include "global.h"

extern const unsigned char helpsect_pluge[];
extern const unsigned char helpsect_smpte_color_bars[];
extern const unsigned char helpsect_color_bars_on_gray[];
extern const unsigned char helpsect_color_bleed[];
extern const unsigned char helpsect_grid[];
extern const unsigned char helpsect_linearity[];
extern const unsigned char helpsect_gray_ramp[];
extern const unsigned char helpsect_sharpness[];
extern const unsigned char helpsect_solid_screen[];
extern const unsigned char helpsect_sharpness[];
extern const unsigned char helpsect_full_screen_stripes[];

#define PFMAP 23
#define PFOVERLAY 22

extern const VBTILE linearity_chrTiles[27];
extern const unsigned int linearity_chrMap[];
extern const VBTILE sharpness_chrTiles[64];
extern const unsigned int sharpness_chrMap[];
const unsigned short gray4pal[] = {
  RGB5( 0, 0, 0),RGB5(15,15,15),RGB5(23,23,23),RGB5(31,31,31)
};
const unsigned short invgray4pal[] = {
  RGB5(31,31,31),RGB5(23,23,23),RGB5(15,15,15),RGB5( 0, 0, 0)
};

void activity_linearity(void) {
  unsigned int inverted = 0;
  unsigned int lcdc_value = MODE_0 | BG1_ON;

  BUP bgtilespec = {
    .SrcNum=sizeof(linearity_chrTiles), .SrcBitNum=2, .DestBitNum=4, 
    .DestOffset=0, .DestOffset0_On=0
  };
  REG_DISPCNT = LCDC_OFF;
  BitUnPack(linearity_chrTiles, PATRAM4(0, 0), &bgtilespec);
  RLUnCompVram(linearity_chrMap, MAP[PFMAP]);
  dma_memset16(MAP[PFOVERLAY], 0x01, 32*20*2);
  REG_DISPCNT = 0;

  while (1) {
    read_pad_help_check(helpsect_linearity);
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_A) {
      lcdc_value ^= BG0_ON;
    }
    if (new_keys & KEY_B) {
      REG_BLDCNT = 0;
      return;
    }

    // This uses blending.
    VBlankIntrWait();
    BGCTRL[1] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFOVERLAY);
    BG_OFFSET[1].x = BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    BG_OFFSET[1].y = 8;
    dmaCopy(inverted ? invgray4pal : gray4pal, BG_COLORS+0x00, sizeof(gray4pal));
    REG_DISPCNT = lcdc_value;
    REG_BLDCNT = 0x2241;  // sub is bg1 and backdrop; main is bg0; function is alpha blend
    REG_BLDALPHA = 0x040C;  // alpha levels: 4/16*sub + 12/16*main
  }
}

void activity_sharpness(void) {
  unsigned int inverted = 0;

  BUP bgtilespec = {
    .SrcNum=sizeof(sharpness_chrTiles), .SrcBitNum=2, .DestBitNum=4, 
    .DestOffset=0, .DestOffset0_On=0
  };
  REG_DISPCNT = LCDC_OFF;
  BitUnPack(sharpness_chrTiles, PATRAM4(0, 0), &bgtilespec);
  RLUnCompVram(sharpness_chrMap, MAP[PFMAP]);
  REG_DISPCNT = 0;

  while (1) {
    read_pad_help_check(helpsect_sharpness);
    if (new_keys & KEY_SELECT) {
      inverted = !inverted;
    }
    if (new_keys & KEY_B) {
      REG_BLDCNT = 0;
      return;
    }

    VBlankIntrWait();
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    dmaCopy(inverted ? invgray4pal : gray4pal, BG_COLORS+0x00, sizeof(gray4pal));
    REG_DISPCNT = MODE_0 | BG0_ON;
  }
}

static void do_bars(void) {
  
}

void activity_smpte(void) {
  
}

void activity_601bars(void) {
  
}

void activity_pluge(void) {
  
}

void activity_gcbars(void) {
  
}

void activity_cps_grid(void) {
  
}

static void do_full_stripes(void) {
  
}

void activity_full_stripes(void) {
  
}

void activity_color_bleed(void) {
  
}

void activity_solid_color(void) {
  
}
