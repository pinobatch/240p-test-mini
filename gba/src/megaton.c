#include "global.h"
#include <gba_input.h>
#include <gba_sound.h>
#include <gba_video.h>

extern const unsigned char helpsect_manual_lag_test[];
#define PFMAP 23
#define NUM_PRESSES 10
#define BLANK_TILE 0x0004

// The "On" and "Off" labels must come first because they cause
// text to be allocated with off at 0x0030 and on at 0x0032
static const char megaton_labels[] =
  "\x83""\x88""off\n"
  "\x84""\x90""on\n"
  "\x38""\x78""Press A when reticles align\n"
  "\x44""\x80""Direction\n"
  "\x83""\x80""\x85\x84\n"  // Left/Right
  "\xA3""\x80""\x86\x87\n"  // Up/Down
  "\x44""\x88""Randomize\n"
  "\x44""\x90""Audio";

void activity_megaton() {
  signed char lag[NUM_PRESSES] = {-1};
  unsigned int x = 129, xtarget = 160;
  unsigned int with_audio = 1, dir = 1, randomize = 1;
  unsigned int progress = 0;

  load_common_bg_tiles();
  load_common_obj_tiles();
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;   // C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing
  REG_SOUNDCNT_L = 0xFF77;  // PSG vol/pan
  REG_SOUND1CNT_L = 0x08;   // no sweep
  dma_memset16(MAP[PFMAP], BLANK_TILE, 32*20*2);
  vwfDrawLabels(megaton_labels, PFMAP, 0x30);

  do {
    read_pad_help_check(helpsect_manual_lag_test);
    
    if (new_keys && KEY_B) {
      break;
    }
    
    oam_used = 0;
    // Draw sprites
    ppu_clear_oam(oam_used);

    VBlankIntrWait();
    REG_DISPCNT = MODE_0 | BG0_ON | OBJ_1D_MAP | OBJ_ON;
    BGCTRL[0] = BG_16_COLOR|BG_WID_32|BG_HT_32|CHAR_BASE(0)|SCREEN_BASE(PFMAP);
    BG_OFFSET[0].x = BG_OFFSET[0].y = 0;
    BG_COLORS[0] = (x == 128 && with_audio) ? RGB5(31, 31, 31) : RGB5(0, 0, 0);
    BG_COLORS[1] = OBJ_COLORS[1] = RGB5(31, 31, 31);
    ppu_copy_oam();

  } while (!(new_keys & KEY_B));
  BG_COLORS[0] = RGB5(0, 0, 0);
  REG_SOUNDCNT_X = 0;  // reset audio
  
  if (new_keys && KEY_B) return;

}
