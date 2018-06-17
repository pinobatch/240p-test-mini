#include <gba_video.h>
#include "global.h"

// Single label:
//     X (1 byte), Y (1 byte, multiple of 8), printable text code units
// Label set:
//     (Single label, '\n')*, Single label, '\0'

/**
 * @param labelset a '\n'-separated, '\0'-terminated list of
 * (x, y, printables)
 * @param nt which nametable (tilemap, screenbaseblock) to draw into
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
    void *chrdst = PATRAM4(0, tilenum & 0x07FF);
    dma_memset16(chrdst, 0x0000, 32 * txtw);
    const char *strend = vwf8Puts(chrdst, labelset + 2, x & 0x07, 1);
    
    // Fill the nametable
    loadMapRowMajor(&(MAP[sbb][y >> 3][x >> 3]), tilenum & 0xF3FF, txtw, 1);
    tilenum += txtw;

    if (*strend == 0) break;
    labelset = strend + 1;
  }
}
