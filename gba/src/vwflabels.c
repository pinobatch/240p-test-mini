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
#include <tonc.h>
#include "global.h"

// Single label:
//     X (1 byte), Y (1 byte, multiple of 8), printable text code units
// Label set:
//     (Single label, '\n')*, Single label, '\0'

/**
 * @param labelset a '\n'-separated, '\0'-terminated list of
 * (x, y, printables)
 * @param nt which SCREENMAT (tilemap, screenbaseblock) to draw into
 * @param tilenum bits 10-0: which tile number to start at;
 * bits 15-11: palette id
 */
void vwfDrawLabels(const char *labelset, unsigned int sbb, unsigned int tilenum) {
  while (1) {
    unsigned int x = labelset[0];
    unsigned int y = labelset[1] & 0xF8;
    unsigned int txtw = vwf8StrWidth(labelset + 2);
    
    // Calculate the width in pixels of tiles occupied by this string,
    // including left and right partial tiles
    txtw += x & 0x07;  // Add left partial tile
    txtw = (((txtw - 1) | 0x07) + 1) >> 3;  // Round up to whole tile

    // Clear this many tiles to color 0 and draw into them using color 1
    void *chrdst = &(tile_mem[0][tilenum & 0x07FF].data);
    memset16(chrdst, 0x0000, 16 * txtw);
    const char *strend = vwf8Puts(chrdst, labelset + 2, x & 0x07, 1);
    
    // Fill the SCREENMAT
    loadMapRowMajor(&(se_mat[sbb][y >> 3][x >> 3]), tilenum & 0xF3FF, txtw, 1);
    tilenum += txtw;

    if (*strend == 0) break;
    labelset = strend + 1;
  }
}
