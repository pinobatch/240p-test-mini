/*
Variable width font label drawing for Game Boy Advance
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

/**
 * @param labels a '\n'-separated list of strings, '\0'-terminated
 * @param positions a list of (x, y) coordinates
 * @param nt which nametable (tilemap, screenbaseblock) to draw into
 * @param tilenum bits 10-0: which tile number to start at;
 * bits 15-11: palette id
 */

void vwfDrawLabelsPositionBased(const char *labels, const char *positions, unsigned int sbb, unsigned int tilenum) {
  while (1) {
    unsigned int x = positions[0];
    unsigned int y = positions[1] & 0xF8;
    unsigned int txtw = vwf8StrWidth(labels);
    
    // Calculate the width in pixels of tiles occupied by this string,
    // including left and right partial tiles
    txtw += x & 0x07;  // Add left partial tile
    txtw = (((txtw - 1) | 0x07) + 1) >> 3;  // Round up to whole tile

    // Clear this many tiles to color 0 and draw into them using color 1
    void *chrdst = tile_mem[0][tilenum & 0x07FF].data;
    dma_memset16(chrdst, 0x0000, 32 * txtw);
    const char *strend = vwf8Puts(chrdst, labels, x & 0x07, 1);
    
    // Fill the nametable
    loadMapRowMajor(&(se_mat[sbb][y >> 3][x >> 3]), tilenum & 0xF3FF, txtw, 1);
    #if defined (__NDS__) && (SAME_ON_BOTH_SCREENS)
    chrdst = tile_mem_sub[0][tilenum & 0x07FF].data;
    dma_memset16(chrdst, 0x0000, 32 * txtw);
    strend = vwf8Puts(chrdst, labels, x & 0x07, 1);
    
    // Fill the nametable
    loadMapRowMajor(&(se_mat_sub[sbb][y >> 3][x >> 3]), tilenum & 0xF3FF, txtw, 1);
    #endif
    tilenum += txtw;

    if (*strend == 0) break;
    labels = strend + 1;
    positions += 2;
  }
}
