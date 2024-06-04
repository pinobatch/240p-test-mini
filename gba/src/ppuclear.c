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

#ifdef __NDS__
void memset16(void *dst, unsigned short c, size_t length_words) {
  u16* dst16 = (u16*)((((uintptr_t)dst)>>1)<<1);
  u32* dst32 = (u32*)(((((uintptr_t)dst)+3)>>2)<<2);
  if(length_words == 0)
    return;
  if(((uintptr_t)dst) & 1) {
    c = ((c & 0xFF) << 8) | (c >> 8);
    *dst16 = ((*dst16) & 0xFF) | (c & 0xFF00);
    length_words--;
    dst16++;
  }
  if(length_words == 0)
    return;
  if(((uintptr_t)dst) & 2) {
    *dst16 = c;
    length_words--;
  }
  u32 final = c | (c << 16);
  for(size_t i = 0; i < (length_words / 2); i++) {
    dst32[i] = final;
  }
  if(length_words & 1) {
    dst16 = (u16*)&dst32[length_words / 2];
    *dst16 = c;
  }
}
#endif

/**
 * Clears all shadow OAM entries from start through 127.
 */
void ppu_clear_oam(size_t start) {
  for (; start < 128; ++start) {
    SOAM[start].attr0 = ATTR0_HIDE;
  }
}

void ppu_copy_oam() {
  #ifdef __NDS__
  CP15_CleanAndFlushDCache();
  #endif
  tonccpy(oam_mem, SOAM, sizeof(SOAM));
  #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
  tonccpy(oam_mem_sub, SOAM, sizeof(SOAM));
  #endif
}

void dma_memset16(void *dst, unsigned int c16, size_t length_bytes) {
  #ifdef __NDS__
  dmaFillHalfWords(c16, dst, length_bytes);
  #else
  dma_fill(dst, c16, length_bytes >> 1, 3, DMA_16|DMA_ENABLE);
  #endif
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
  #ifdef __NDS__
  CP15_CleanAndFlushDCache();
  #endif
  for (; h > 0; --h) {
    tonccpy(dst, src, w * 2);
    src += w;
    dst += 32;
  }
}
