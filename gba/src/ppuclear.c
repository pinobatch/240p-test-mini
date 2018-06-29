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
#include <gba_dma.h>
#include <gba_compression.h>

EWRAM_BSS OBJATTR SOAM[128];
unsigned char oam_used;

/**
 * Clears all shadow OAM entries from start through 127.
 */
void ppu_clear_oam(size_t start) {
  for (; start < 128; ++start) {
    SOAM[start].attr0 = OBJ_DISABLE;
  }
}

void ppu_copy_oam() {
  dmaCopy(SOAM, OAM, sizeof(SOAM));
}

void dma_memset16(void *dst, unsigned int c16, size_t n) {
  volatile unsigned short src = c16;
  DMA_Copy(3, &src, dst, DMA_SRC_FIXED | DMA16 | (n>>1));
}

void bitunpack2(void *restrict dst, const void *restrict src, size_t len) {
  // Load tiles
  BUP bgtilespec = {
    .SrcNum=len, .SrcBitNum=2, .DestBitNum=4, 
    .DestOffset=0, .DestOffset0_On=0
  };
  BitUnPack(src, dst, &bgtilespec);
}

void bitunpack1(void *restrict dst, const void *restrict src, size_t len) {
  // Load tiles
  BUP bgtilespec = {
    .SrcNum=len, .SrcBitNum=1, .DestBitNum=4, 
    .DestOffset=0, .DestOffset0_On=0
  };
  BitUnPack(src, dst, &bgtilespec);
}

void load_flat_map(unsigned short *dst, const unsigned short *src, unsigned int w, unsigned int h) {
  for (; h > 0; --h) {
    dmaCopy(src, dst, w * 2);
    src += w;
    dst += 32;
  }
}
