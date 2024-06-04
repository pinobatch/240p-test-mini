/*
Variable and function declarations for 160p Test Suite
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
#ifndef GLOBAL_H
#define GLOBAL_H
#include <stdint.h>
#include <sys/types.h>
#include "cross_compatibility.h"
#include "helppages.h"

// Size of a statically sized array
#define count(array) (sizeof((array)) / sizeof((array)[0]))

#define GET_SLICE_X(e, y, x) ((((e) * (x)) + (((y) + 1) / 2)) / (y))

typedef void (*activity_func)(void);

// help.c
#define HELP_LINE_LEN 48
extern char help_line_buffer[HELP_LINE_LEN];
extern unsigned char help_bg_loaded, help_wanted_page, help_cursor_y;
extern signed char help_wnd_progress;
unsigned int helpscreen(helpdoc_kind doc_num, unsigned int keymask);
unsigned int read_pad_help_check(helpdoc_kind doc_num);

// stills.c

typedef struct BarsListEntry {
  unsigned short l, t, r, b, color;
} BarsListEntry;
void draw_barslist(const BarsListEntry *rects);

extern const unsigned short gray4pal[4];
extern const unsigned short invgray4pal[4];
void activity_monoscope(void);
void activity_sharpness(void);
void activity_smpte(void);
void activity_601bars(void);
void activity_pluge(void);
void activity_gcbars(void);
void activity_gray_ramp(void);
void activity_full_stripes(void);
void activity_color_bleed(void);
void activity_solid_color(void);
void activity_convergence(void);

// scrolltest.c
void activity_grid_scroll(void);
void hill_zone_load_bg(void);
void hill_zone_set_scroll(uint16_t *hdmaTable, unsigned int x);
void activity_hill_zone_scroll(void);
void activity_kiki_scroll(void);

// placeholder.c
void load_common_bg_tiles(void);
void load_common_obj_tiles(void);
void lame_boy_demo(void);

// motionblur.c
void activity_motion_blur(void);

// overscan.c
void activity_overscan(void);

// stopwatch.c
void activity_stopwatch(void);

// backlight.c
void activity_backlight_zone(void);

// shadowsprite.c
void activity_shadow_sprite(void);

// megaton.c
void activity_megaton(void);

// soundtest.c
#ifdef __NDS__
enum sound_id_e {
    BEEP_1K_SOUND_ID = 0,
    TICK_SOUND_ID = 1,
    PRESS_A_SOUND_ID = 2
};
typedef enum sound_id_e sound_id;
#define NUM_SOUND_IDS 3

void initAllSounds(void);
void killAllSounds(void);
void startPlayingSound(sound_id wanted_id);
void killPlayingSound(sound_id wanted_id);
#else
extern const unsigned char waveram_sin2x[16];
#endif
void activity_sound_test(void);

// audiosync.c
void activity_audio_sync(void);

// pads.c
extern unsigned short cur_keys, new_keys, das_keys, das_timer;
unsigned int read_pad(void);
unsigned int autorepeat(unsigned int allowed_keys);

// ppuclear.c
typedef unsigned short VBTILE[8];
typedef unsigned char ONEBTILE[8];
extern unsigned char oam_used;
extern OBJ_ATTR SOAM[128];
void ppu_clear_oam(size_t start);
void ppu_copy_oam(void);
void dma_memset16(void *s, unsigned int c, size_t n);
void bitunpack2(void *restrict dst, const void *restrict src, size_t len);
void bitunpack1(void *restrict dst, const void *restrict src, size_t len);
void load_flat_map(unsigned short *dst, const unsigned short *src, unsigned int w, unsigned int h);

// rand.c
void lcg_srand(unsigned int in_seed);
int lcg_rand(void);
#define LCG_RAND_MAX 65535

// vwfdraw.c
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height);
void vwf8PutTile(u32 *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color);
const char *vwf8Puts(u32 *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color);
unsigned int vwf8StrWidth(const char *s);

// vwflabels.c
void vwfDrawLabelsPositionBased(const char *labels, const char *positions, unsigned int sbb, unsigned int tilenum);

#endif
