/*
Sound test for 160p Test Suite
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

// PSG //////////////////////////////////////////////////////////////

// Sine waves for PSG channel 3
#ifdef __NDS__
#include "8khz_bin.h"
#include "4khz_bin.h"
#include "2khz_bin.h"
#include "1khz_bin.h"
#include "500hz_bin.h"
#include "sound_tick_bin.h"
#include "sound_press_a_bin.h"

#define BOTH_SPEAKERS_PANNING 64
#define LEFT_SPEAKER_PANNING 0
#define RIGHT_SPEAKER_PANNING 127

#define FULL_VOLUME 127

static int sound_ids[NUM_SOUND_IDS];
#else
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
#endif

static void wait24(void) {
  ((volatile u16 *)BG_PALETTE)[6] = RGB5(31, 0, 0);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  ((volatile u16 *)BG_PALETTE_SUB)[6] = RGB5(31, 0, 0);
  #endif
  for (unsigned int i = 24; i > 0; --i) {
    VBlankIntrWait();
    dma_memset16(BG_PALETTE + 6, RGB5(31, 0, 0), 2);
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    dma_memset16(BG_PALETTE_SUB + 6, RGB5(31, 0, 0), 2);
    #endif
  }
  BG_PALETTE[6] = RGB5(31, 31, 31);
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  BG_PALETTE_SUB[6] = RGB5(31, 31, 31);
  #endif
}

#ifndef __NDS__
static void reinitAudio(void) {
  REG_SOUNDCNT_X = 0x0000;  // 00: reset
  REG_SOUNDCNT_X = 0x0080;  // 80: run
  REG_SOUNDBIAS = 0xC200;  // 4200: 65.5 kHz PWM (for PCM); C200: 262 kHz PWM (for PSG)
  REG_SOUNDCNT_H = 0x0B06;  // xBxx: PCM A centered from timer 0; PSG/PCM full mix
}
#endif

#ifdef __NDS__
static void beepTri(const unsigned char *pcm8_data, unsigned int divider, unsigned int size, unsigned char panning) {
  int curr_sound_id = soundPlaySample(pcm8_data, SoundFormat_8Bit, size, 64000/divider, FULL_VOLUME, panning, true, 0);
  wait24();
  soundKill(curr_sound_id);
}
#else
static void beepTri(const unsigned char *wave, unsigned int period) {
  REG_SOUND3CNT_L = 0;  // unlock waveram
  dmaCopy(wave, (void *)WAVE_RAM, 16);
  REG_SOUND3CNT_L = 0xC0;    // lock waveram
  REG_SOUND3CNT_H = 0x2000;  // full volume
  REG_SOUND3CNT_X = (2048 - period) + 0x8000;  // pitch
  wait24();
  REG_SOUND3CNT_H = 0;
}
#endif

static void beep8k(void) {
  #ifdef __NDS__
  beepTri(_8khz_bin, 1, sizeof(_8khz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sin16x, 131);
  #endif
}

static void beep4k(void) {
  #ifdef __NDS__
  beepTri(_4khz_bin, 1, sizeof(_4khz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sin8x, 131);
  #endif
}

static void beep2k(void) {
  #ifdef __NDS__
  beepTri(_2khz_bin, 1, sizeof(_2khz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sin4x, 131);
  #endif
}

static void beep1k(void) {
  #ifdef __NDS__
  beepTri(_1khz_bin, 1, sizeof(_1khz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sin2x, 131);
  #endif
}

static void beep500(void) {
  #ifdef __NDS__
  beepTri(_500hz_bin, 1, sizeof(_500hz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sinx, 131);
  #endif
}

static void beep250(void) {
  #ifdef __NDS__
  beepTri(_500hz_bin, 2, sizeof(_500hz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sinx, 262);
  #endif
}

static void beep125(void) {
  #ifdef __NDS__
  beepTri(_500hz_bin, 4, sizeof(_500hz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sinx, 524);
  #endif
}

static void beep62(void) {
  #ifdef __NDS__
  beepTri(_500hz_bin, 8, sizeof(_500hz_bin), BOTH_SPEAKERS_PANNING);
  #else
  beepTri(waveram_sinx, 1048);
  #endif
}

static void beep1kL(void) {
  #ifdef __NDS__
  beepTri(_1khz_bin, 1, sizeof(_1khz_bin), LEFT_SPEAKER_PANNING);
  #else
  REG_SOUNDCNT_L = 0xF077;
  beep1k();
  #endif
}

static void beep1kR(void) {
  #ifdef __NDS__
  beepTri(_1khz_bin, 1, sizeof(_1khz_bin), RIGHT_SPEAKER_PANNING);
  #else
  REG_SOUNDCNT_L = 0x0F77;
  beep1k();
  #endif
}

static void beepPulse(void) {
  #ifdef __NDS__
  int curr_sound_id = soundPlayPSG(DutyCycle_50, 8000, (FULL_VOLUME * 2) / 3, BOTH_SPEAKERS_PANNING);
  #else
  REG_SOUND1CNT_L = 0x08;    // no sweep
  REG_SOUND1CNT_H = 0xA080;  // 2/3 volume, 50% duty
  REG_SOUND1CNT_X = (2048 - 131) + 0x8000;  // pitch
  #endif
  wait24();
  #ifdef __NDS__
  soundKill(curr_sound_id);
  #else
  REG_SOUND1CNT_H = 0;
  REG_SOUND1CNT_X = 0x8000;  // note cut
  #endif
}

static void beepSurround(void) {
  #ifdef __NDS__
  int curr_sound_id[2];
  curr_sound_id[0] = soundPlayPSG(DutyCycle_25, 8000, (FULL_VOLUME * 2) / 3, LEFT_SPEAKER_PANNING);
  curr_sound_id[1] = soundPlayPSG(DutyCycle_75, 8000, (FULL_VOLUME * 2) / 3, RIGHT_SPEAKER_PANNING);
  #else
  reinitAudio();
  REG_SOUNDCNT_L = 0xD277;
  REG_SOUND1CNT_L = 0x08;    // no sweep
  REG_SOUND1CNT_H = 0xA040;  // 2/3 volume, 25% duty
  REG_SOUND2CNT_L = 0xA0C0;  // 2/3 volume, 75% duty
  REG_SOUND1CNT_X = (2048 - 131) + 0x8000;  // pitch
  REG_SOUND2CNT_H = (2048 - 131) + 0x8000;  // pitch
  #endif
  wait24();
  #ifdef __NDS__
  soundKill(curr_sound_id[0]);
  soundKill(curr_sound_id[1]);
  #else
  REG_SOUND1CNT_H = 0;
  REG_SOUND1CNT_X = 0x8000;  // note cut
  REG_SOUND2CNT_L = 0;
  REG_SOUND2CNT_H = 0x8000;  // note cut
  #endif
}

static void beepHiss(void) {
  #ifdef __NDS__
  int curr_sound_id = soundPlayNoise(8000, (FULL_VOLUME * 2) / 3, BOTH_SPEAKERS_PANNING);
  #else
  REG_SOUND4CNT_L = 0xA000;  // 2/3 volume
  REG_SOUND4CNT_H = 0x8024;  // divider
  #endif
  wait24();
  #ifdef __NDS__
  soundKill(curr_sound_id);
  #else
  REG_SOUND4CNT_L = 0;
  REG_SOUND4CNT_H = 0x8000;  // note cut
  #endif
}

static void beepBuzz(void) {
  #ifdef __NDS__
  int curr_sound_id = soundPlayPSG(DutyCycle_50, 1000, (FULL_VOLUME * 2) / 3, BOTH_SPEAKERS_PANNING);
  #else
  REG_SOUND4CNT_L = 0xA000;  // 2/3 volume
  REG_SOUND4CNT_H = 0x802C;  // divider
  #endif
  wait24();
  #ifdef __NDS__
  soundKill(curr_sound_id);
  #else
  REG_SOUND4CNT_L = 0;
  REG_SOUND4CNT_H = 0x8000;  // note cut
  #endif
}

#ifdef __NDS__
void initAllSounds(void) {
  for(int i = 0; i < NUM_SOUND_IDS; i++)
    sound_ids[i] = -1;
}

void killAllSounds(void) {
  for(int i = 0; i < NUM_SOUND_IDS; i++)
    if(sound_ids[i] != -1) {
      soundKill(sound_ids[i]);
      sound_ids[i] = -1;
    }
}

void startPlayingSound(sound_id wanted_id) {
  const unsigned char *pcm8_data = NULL;
  unsigned int size = 0;
  switch(wanted_id) {
    case BEEP_1K_SOUND_ID:
      pcm8_data = _1khz_bin;
      size = sizeof(_1khz_bin);
    break;
    case TICK_SOUND_ID:
      pcm8_data = sound_tick_bin;
      size = sizeof(sound_tick_bin);
    break;
    case PRESS_A_SOUND_ID:
      pcm8_data = sound_press_a_bin;
      size = sizeof(sound_press_a_bin);
    break;
    default:
      return;
  }
  if(sound_ids[wanted_id] != -1) {
    soundResume(sound_ids[wanted_id]);
    return;
  }
  sound_ids[wanted_id] = soundPlaySample(pcm8_data, SoundFormat_8Bit, size, 64000, FULL_VOLUME, BOTH_SPEAKERS_PANNING, true, 0);
}

void killPlayingSound(sound_id wanted_id) {
  if(wanted_id >= NUM_SOUND_IDS)
    return;
  if(sound_ids[wanted_id] != -1) {
    soundKill(sound_ids[wanted_id]);
    sound_ids[wanted_id] = -1;
  }
}
#endif
// PCM demo /////////////////////////////////////////////////////////
#ifndef __NDS__

typedef struct ChordVoice {
  unsigned short delaylinestart, delaylineend;
  unsigned char fac1, fac2;
} ChordVoice;

#define PCM_NUM_VOICES 6
#define PCM_PERIOD 924   // 16777216 tstates/s / 18157 samples/s
#define PCM_BUF_LEN 304  // 280896 tstates/frame / PCM_PERIOD

EWRAM_BSS static signed short delayline[672];
EWRAM_BSS static signed short mixbuf[PCM_BUF_LEN];
EWRAM_BSS static signed char playbuf[2][PCM_BUF_LEN];

static const ChordVoice voices[PCM_NUM_VOICES] = {
  {  0, 186, 1, 3},
  {186, 334, 3, 1},
  {334, 458, 3, 1},
  {458, 551, 3, 1},
  {551, 625, 3, 1},
  {625, 672, 3, 1},
};

IWRAM_CODE static void beepPCM(void) {
  unsigned short phases[PCM_NUM_VOICES];
  unsigned int frames = 0;
  
  dma_memset16(delayline, 0, sizeof(delayline));
  dma_memset16(playbuf, 0, sizeof(playbuf));
  for(unsigned int ch = 0; ch < PCM_NUM_VOICES; ++ch) {
    unsigned int i = voices[ch].delaylinestart;
    phases[ch] = i;
    dma_memset16(delayline + i, i & 1 ? -10240 : 10240,
                 (voices[ch].delaylineend - i) / 4);
  }
  
  ((volatile u16 *)BG_PALETTE)[6] = RGB5(31, 0, 0);
  REG_TM0CNT_L = 65536 - PCM_PERIOD;  // 18157 Hz
  REG_TM0CNT_H = 0x0080;  // enable timer
  REG_SOUNDBIAS = 0x4200;  // 65.5 kHz PWM (for PCM)

  do {
    read_pad();
    dma_memset16(mixbuf, 0, sizeof(mixbuf));
    for (unsigned int i = 0; i <= frames && i < PCM_NUM_VOICES; ++i) {
      unsigned int phase = phases[i];
      for (unsigned int t = 0; t < PCM_BUF_LEN; ++t) {
        mixbuf[t] += delayline[phase];
        unsigned int nextphase = phase + 1;
        if (nextphase >= voices[i].delaylineend) {
          nextphase = voices[i].delaylinestart;
        }
        signed int newsample = voices[i].fac1 * delayline[phase];
        newsample += voices[i].fac2 * delayline[nextphase] + 2;
        newsample = newsample * ((i >= 4) ? 511 : 510) / 2048;
        delayline[phase] = newsample;
        phase = nextphase;
      }
      phases[i] = phase;
    }
    signed char *next_playbuf = playbuf[frames & 0x01];
    for (unsigned int t = 0; t < PCM_BUF_LEN; ++t) {
      next_playbuf[t] = mixbuf[t] >> 8;
    }

    VBlankIntrWait();
    REG_DMA1CNT = 0;
    REG_DMA1SAD = (unsigned long)next_playbuf;
    REG_DMA1DAD = 0x040000A0;    // write to PCM A's FIFO
    REG_DMA1CNT = 0xB6000000;    // DMA timed by FIFO, 32 bit repeating inc src
    frames += 1;
  } while (!new_keys && frames < 400);
  REG_TM0CNT_H = 0;  // stop timer
  REG_DMA1CNT = 0;   // stop DMA
  BG_PALETTE[6] = RGB5(31, 31, 31);
  REG_SOUNDBIAS = 0xC200;  // 65.5 kHz PWM (for PCM)
}
#endif

// Sound test menu //////////////////////////////////////////////////

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
  beepSurround,
  beepHiss,
  beepBuzz,
  #ifndef __NDS__
  beepPCM
  #endif
};
void activity_sound_test() {
  #ifdef __NDS__
  soundEnable();
  #else
  reinitAudio();
  #endif

  while (1) {
    #ifndef __NDS__
    REG_SOUNDCNT_L = 0xFF77;  // reset PSG vol/pan
    #endif
    helpscreen(helpsect_sound_test_frequency, KEY_A|KEY_START|KEY_B|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT);

    if (new_keys & KEY_B) {
      #ifdef __NDS__
      soundDisable();
      #else
      REG_SOUNDCNT_X = 0;  // reset audio
      #endif
      return;
    }
    if (new_keys & KEY_START) {
      unsigned int last_page = help_wanted_page;
      unsigned int last_y = help_cursor_y;
      help_wanted_page = last_page;
      help_cursor_y = last_y;
      helpscreen(helpsect_sound_test, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
    } else {
      sound_test_handlers[help_cursor_y]();
    }
  }
  lame_boy_demo();
}
