#ifndef GLOBAL_H
#define GLOBAL_H
#include <stdint.h>
#include <sys/types.h>
#include <gba_sprites.h>
#include <gba_systemcalls.h>

// Size of a statically sized array
#define count(array) (sizeof((array)) / sizeof((array)[0]))

typedef void (*activity_func)(void);

// help.c
#define HELP_LINE_LEN 48
extern char help_line_buffer[HELP_LINE_LEN];
extern unsigned char help_bg_loaded, help_wanted_page, help_cursor_y;
extern signed char help_wnd_progress;
unsigned int helpscreen(unsigned int doc_num, unsigned int keymask);
unsigned int read_pad_help_check(const void *doc_num_as_ptr);

// stills.c

typedef struct BarsListEntry {
  unsigned char l, t, r, b, color;
} BarsListEntry;
void draw_barslist(const BarsListEntry *rects);

extern const unsigned short gray4pal[4];
extern const unsigned short invgray4pal[4];
void activity_linearity(void);
void activity_sharpness(void);
void activity_smpte(void);
void activity_601bars(void);
void activity_pluge(void);
void activity_gcbars(void);
void activity_gray_ramp(void);
void activity_cps_grid(void);
void activity_full_stripes(void);
void activity_color_bleed(void);
void activity_solid_color(void);

// scrolltest.c
void activity_grid_scroll(void);
void load_hill_zone_bg(void);
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
extern const unsigned char waveram_sin2x[16];
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
extern OBJATTR SOAM[128];
void ppu_clear_oam(size_t start);
void ppu_copy_oam(void);
void dma_memset16(void *s, unsigned int c, size_t n);
void bitunpack2(void *restrict dst, const void *restrict src, size_t len);
void bitunpack1(void *restrict dst, const void *restrict src, size_t len);

// rand.c
void lcg_srand(unsigned int in_seed);
int lcg_rand(void);
#define LCG_RAND_MAX 65535

// vwfdraw.c
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height);
void vwf8PutTile(uint32_t *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color);
const char *vwf8Puts(uint32_t *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color);
unsigned int vwf8StrWidth(const char *s);

// vwflabels.c
void vwfDrawLabels(const char *labelset, unsigned int sbb, unsigned int tilenum);

#endif