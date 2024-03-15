/*
Variable width font drawing for Game Boy Advance
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
#include <stdint.h>
#include "global.h"
#include "vwf7.h"

#if 0
typedef struct VWFCanvas {
  uint32_t *data;
  unsigned short width, height;
} VWFCanvas;

/**
 * Fills a tilemap with a rectangle of tile numbers that ascend
 * in column-major order.
 * @param dst &(MAP[mapnum][y][x])
 * @param tilenum palette and tile number of tile
 * @param width width of text box in tiles
 * @param height height of text
 */
void loadMapColMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height) {
  for (unsigned int rows_left = height;
       rows_left > 0;
       --rows_left) {
    unsigned short *rowptr = dst;
    unsigned int rowtilenum = tilenum;
    for (unsigned int cols_left = width;
         cols_left >= 0;
         --cols_left) {
      *dst++ = rowtilenum;
      rowtilenum += height;
    }
    tilenum += 1;
    dst += 32;
  }
}
#endif


/**
 * Fills a tilemap with a rectangle of tile numbers that ascend
 * in row-major order.
 * @param dst &(BG[mapnum][y][x])
 * @param tilenum palette and tile number of tile
 * @param width width of text box in tiles
 * @param height height of text
 */
void loadMapRowMajor(unsigned short *dst, unsigned int tilenum,
                     unsigned int width, unsigned int height) {
  for (; height > 0; --height) {
    unsigned short *rowptr = dst;
    for (unsigned int cols_left = width;
         cols_left > 0;
         --cols_left) {
      *rowptr++ = tilenum++;
    }
    dst += 32;
  }
}

#define FIRST_PRINTABLE_CU 0x18

void vwf8PutTile(uint32_t *dst, unsigned int glyphnum,
                 unsigned int x, unsigned int color) {
  const unsigned char *glyph = vwfChrData[glyphnum - FIRST_PRINTABLE_CU];
  unsigned int startmask = 0x0F << ((x & 0x07) * 4);
  dst += (x >> 3) << 3;
  color = (color & 0x0F) * 0x11111111;
  
  for (unsigned int htleft = 8; htleft > 0; --htleft) {
    unsigned int mask = startmask;
    unsigned int glyphdata = *glyph++;
    uint32_t *sliver = dst++;
    
    for(; glyphdata; glyphdata >>= 1) {
      if (glyphdata & 0x01) {
        uint32_t s = *sliver;
        *sliver = ((s ^ color) & mask) ^ s;
      }
      mask <<= 4;
      if (mask == 0) {
        mask = 0x0F;
        sliver += 8;
      }
    }
  }
}

/**
 * @return the address of the terminating control character
 */
const char *vwf8Puts(uint32_t *restrict dst, const char *restrict s,
                     unsigned int x, unsigned int color) {
  while (x < SCREEN_WIDTH) {
    unsigned char c = *s & 0xFF;
    if (c < FIRST_PRINTABLE_CU) return s;
    ++s;
    vwf8PutTile(dst, c, x, color);
    x += vwfChrWidths[c - FIRST_PRINTABLE_CU];
  }
  return s;
}

unsigned int vwf8StrWidth(const char *s) {
  unsigned int x = 0;

  while (x < SCREEN_WIDTH) {
    unsigned char c = *s & 0xFF;
    if (c < FIRST_PRINTABLE_CU) return x;
    ++s;
    x += vwfChrWidths[c - FIRST_PRINTABLE_CU];
  }
  return x;
}
