/*
Basic video functions for Game Boy Advance
Copyright 2018 Damian Yerrick

This work is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any
damages arising from the use of this work.

Permission is granted to anyone to use this work for any purpose,
including commercial applications, and to alter it and redistribute
it freely, subject to the following restrictions:

1. The origin of this work must not be misrepresented; you must
   not claim that you wrote the original work. If you use
   this work in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original work.
3. This notice may not be removed or altered from any source
   distribution.

"Source" is the preferred form of a work for making changes to it.

*/
#include "global.h"


EWRAM_BSS OBJ_ATTR SOAM[128];
unsigned char oam_used;

/**
 * Clears all shadow OAM entries from start through 127.
 */
void ppu_clear_oam(size_t start) {
  for (; start < 128; ++start) {
    SOAM[start].attr0 = ATTR0_HIDE;
  }
}

void ppu_copy_oam() {
  tonccpy(oam_mem, SOAM, sizeof(SOAM));
}

void dma_memset16(void *dst, unsigned int c16, size_t length_bytes) {
  dma_fill(dst, c16, length_bytes >> 1, 3, DMA_16|DMA_ENABLE);
}

void bitunpack2(void *restrict dst, const void *restrict src, size_t len) {
  // Load tiles
  BUP bgtilespec = {
    .src_len=len, .src_bpp=2, .dst_bpp=4, 
    .dst_ofs=0
  };
  BitUnPack(src, dst, &bgtilespec);
}

void bitunpack1(void *restrict dst, const void *restrict src, size_t len) {
  // Load tiles
  BUP bgtilespec = {
    .src_len=len, .src_bpp=1, .dst_bpp=4, 
    .dst_ofs=0
  };
  BitUnPack(src, dst, &bgtilespec);
}

void load_flat_map(unsigned short *dst, const unsigned short *src, unsigned int w, unsigned int h) {
  for (; h > 0; --h) {
    tonccpy(dst, src, w * 2);
    src += w;
    dst += 32;
  }
}
