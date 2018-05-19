#include "global.h"
#include <gba_dma.h>

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
