#ifndef GLOBAL_H
#define GLOBAL_H
#include <stdint.h>
#include <sys/types.h>
#include <gba_sprites.h>
#include <gba_systemcalls.h>

// help.c
#define HELP_LINE_LEN 48
extern unsigned char help_line_buffer[HELP_LINE_LEN];
extern unsigned char help_bg_loaded;
void helpscreen(unsigned int doc_num, unsigned int keymask);

// stills.c
void activity_linearity(void);

// placeholder.c
void lame_boy_demo(void);

// ppuclear.c
typedef unsigned short VBTILE[16];
extern unsigned char oam_used;
extern OBJATTR SOAM[128];
void ppu_clear_oam(size_t start);
void ppu_copy_oam(void);
void dma_memset16(void *s, unsigned int c, size_t n);

// vwfdraw.c
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height);
void vwf8PutTile(uint32_t *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color);
const char *vwf8Puts(uint32_t *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color);
unsigned int vwf8StrWidth(const char *s);

#endif