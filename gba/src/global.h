#ifndef GLOBAL_H
#define GLOBAL_H
#include <stdint.h>
#include <sys/types.h>
#include <gba_sprites.h>
#include <gba_systemcalls.h>

// help
#define HELP_LINE_LEN 48
unsigned char help_line_buffer[HELP_LINE_LEN];
unsigned char help_bg_loaded;


// placeholder.c
void lame_boy_demo(void);

// ppuclear.c
typedef unsigned short GBATilemap[32][32];
#define BG ((GBATilemap *)VRAM)
extern unsigned char oam_used;
extern OBJATTR SOAM[128];
void ppu_clear_oam(size_t start);
void ppu_copy_oam(void);

// vwfdraw.c
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height);
void vwf8PutTile(uint32_t *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color);
const char *vwf8Puts(uint32_t *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color);
unsigned int vwf8StrWidth(const char *s);

#endif