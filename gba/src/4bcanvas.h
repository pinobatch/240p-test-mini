/*
Variable width font drawing library for DS (and GBA)

Copyright 2007-2018 Damian Yerrick <pinoandchester@pineight.com>

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

#ifndef P8_CANVAS_H
#define P8_CANVAS_H

#include <stdint.h>
#include "cross_compatibility.h"

typedef struct TileCanvas {
  uint8_t left;    // in 8 pixel units on nametable
  uint8_t top;     // in 8 pixel units on nametable
  uint8_t width;   // in 8 pixel units on nametable
  uint8_t height;  // in 8 pixel units on nametable
  uint32_t *chrBase;
  uint8_t map;  // in 2 KiB units on VRAM
  uint8_t core;    // 0: main; 1: sub
  uint16_t mapTileBase;
  NAMETABLE *mapBase;
} TileCanvas;

extern const TileCanvas screen;
#ifdef __NDS__
extern const TileCanvas screen_sub;
#endif

void canvasClear(const TileCanvas *src, unsigned int color);
void canvasInit(const TileCanvas *src, unsigned int color);
void canvasRectfill(const TileCanvas *v,
                    int l, int t, int r, int b,
                    int c);
void canvasHline(const TileCanvas *v, int l, int t, int r, int c);
void canvasVline(const TileCanvas *v, int l, int t, int b, int c);
void canvasRect(const TileCanvas *v, int l, int t, int r, int b, int c);

#endif
