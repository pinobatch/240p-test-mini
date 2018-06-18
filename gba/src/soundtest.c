#include "global.h"
#include <gba_input.h>
#include <gba_sound.h>
#include <gba_dma.h>
#include <gba_video.h>

// Sine waves for PCM
const unsigned char waveram_sinx[16] __attribute__((aligned (2))) = {
  0x8a,0xbc,0xde,0xff,0xff,0xed,0xcb,0xa8,0x75,0x43,0x21,0x00,0x00,0x12,0x34,0x57
};
const unsigned char waveram_sin2x[16] __attribute__((aligned (2))) = {
  0x9c,0xef,0xfe,0xc9,0x63,0x10,0x01,0x36,0x9c,0xef,0xfe,0xc9,0x63,0x10,0x01,0x36
};
const unsigned char waveram_sin4x[16] __attribute__((aligned (2))) = {
  0xbf,0xfb,0x40,0x04,0xbf,0xfb,0x40,0x04,0xbf,0xfb,0x40,0x04,0xbf,0xfb,0x40,0x04
};
const unsigned char waveram_sin8x[16] __attribute__((aligned (2))) = {
  0xcc,0x33,0xcc,0x33,0xcc,0x33,0xcc,0x33,0xcc,0x33,0xcc,0x33,0xcc,0x33,0xcc,0x33
};
const unsigned char waveram_sin16x[16] __attribute__((aligned (2))) = {
  0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3
};

// Sound test menu

extern const unsigned char helpsect_sound_test_frequency[];
extern const unsigned char helpsect_sound_test[];

#define DOC_MENU ((unsigned int)helpsect_sound_test_frequency)
#define DOC_HELP ((unsigned int)helpsect_sound_test)

static void wait24() {
  ((volatile u16 *)BG_COLORS)[6] = RGB5(31, 0, 0);
  for (unsigned int i = 24; i > 0; --i) {
    VBlankIntrWait();
    dma_memset16(BG_COLORS + 6, RGB5(31, 0, 0), 2);
  }
  BG_COLORS[6] = RGB5(31, 31, 31);
}

static void beepTri(const unsigned char *wave, unsigned int period) {
  REG_SOUND3CNT_L = 0;  // unlock waveram
  dmaCopy(wave, (void *)WAVE_RAM, 16);
  REG_SOUND3CNT_L = 0xC0;    // lock waveram
  REG_SOUND3CNT_H = 0x2000;  // full volume
  REG_SOUND3CNT_X = (2048 - period) + 0x8000;  // pitch
  wait24();
  REG_SOUND3CNT_H = 0;
}

static void beep8k(void) {
  beepTri(waveram_sin16x, 131);
}

static void beep4k(void) {
  beepTri(waveram_sin8x, 131);
}

static void beep2k(void) {
  beepTri(waveram_sin4x, 131);
}

static void beep1k(void) {
  beepTri(waveram_sin2x, 131);
}

static void beep500(void) {
  beepTri(waveram_sinx, 131);
}

static void beep250(void) {
  beepTri(waveram_sinx, 262);
}

static void beep125(void) {
  beepTri(waveram_sinx, 524);
}

static void beep62(void) {
  beepTri(waveram_sinx, 1048);
}

static void beep1kL(void) {
  REG_SOUNDCNT_L = 0xF077;
  beep1k();
}

static void beep1kR(void) {
  REG_SOUNDCNT_L = 0x0F77;
  beep1k();
}

static void beepPulse(void) {
  REG_SOUND1CNT_L = 0x08;    // no sweep
  REG_SOUND1CNT_H = 0xA080;  // 2/3 volume, 50% duty
  REG_SOUND1CNT_X = (2048 - 131) + 0x8000;  // pitch
  wait24();
  REG_SOUND1CNT_H = 0;
  REG_SOUND1CNT_X = 0x8000;  // note cut
}

static void beepHiss(void) {
  REG_SOUND4CNT_L = 0xA000;  // 2/3 volume
  REG_SOUND4CNT_H = 0x8024;  // divider
  wait24();
  REG_SOUND4CNT_L = 0;
  REG_SOUND4CNT_H = 0x8000;  // note cut
}

static void beepBuzz(void) {
  REG_SOUND4CNT_L = 0xA000;  // 2/3 volume
  REG_SOUND4CNT_H = 0x802C;  // divider
  wait24();
  REG_SOUND4CNT_L = 0;
  REG_SOUND4CNT_H = 0x8000;  // note cut
}

static void beepPCM(void) {
  lame_boy_demo();
}

static const activity_func sound_test_handlers[] = {
  beep8k,
  beep4k,
  beep2k,
  beep1k,
  beep500,
  beep250,
  beep125,
  beep62,
  beep1kL,
  beep1kR,
  beepPulse,
  beepHiss,
  beepBuzz,
  beepPCM,
};
void activity_sound_test() {
  REG_SOUNDCNT_X = 0x0080;  // 00: reset; 80: run
  REG_SOUNDBIAS = 0xC200;  // 4200: 65.5 kHz PWM (for PCM); C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0002;  // PSG/PCM mixing

  while (1) {
    REG_SOUNDCNT_L = 0xFF77;  // reset PSG vol/pan
    helpscreen(DOC_MENU, KEY_A|KEY_START|KEY_B|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT);

    if (new_keys & KEY_B) {
      REG_SOUNDCNT_X = 0;  // reset audio
      return;
    }
    if (new_keys & KEY_START) {
      unsigned int last_page = help_wanted_page;
      unsigned int last_y = help_cursor_y;
      help_wanted_page = last_page;
      help_cursor_y = last_y;
      helpscreen(DOC_HELP, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    } else {
      sound_test_handlers[help_cursor_y]();
    }
  }
  lame_boy_demo();
}
