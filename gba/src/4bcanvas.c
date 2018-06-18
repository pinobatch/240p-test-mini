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

// This was originally developed in 2007 for an Animal Crossing
// related project.

#include "4bcanvas.h"
#include <sys/types.h>
#include <gba_video.h>
void dma_memset16(void *dst, unsigned int c16, size_t n);

const TileCanvas screen = {
  .left = 0, .top = 0, .width = 32, .height = 24,
  .chrBase = (uint32_t *)PATRAM4(0, 0),
  .map = 23,
  .core = 0,
  .mapTileBase = 0
};

static
void fillcol(uint32_t *dst, unsigned int colStride,
             unsigned int l, unsigned int t,
             unsigned int r, unsigned int b,
             unsigned int c)
{
  uint32_t mask = 0xffffffffU << (4 * l);
  mask &= 0xffffffffU >> (4 * (8 - r));
  c &= mask;
  mask = ~mask;

  for (; t < b; t++) {
    dst[t] = (dst[t] & mask) | c;
  }
}

void canvasRectfill(const TileCanvas *v, int l, int t, int r, int b, int c)
{
  uint32_t *dst = v->chrBase;
  c &= 0x0000000F;
  c *= 0x11111111;

  unsigned int x = l;
  unsigned int stride = v->height * 8;
  uint32_t *tile = dst + stride * (l >> 3);

  if (t < 0) {
    t = 0;
  }
  if (b > v->height * 8) {
    b = v->height * 8;
  }

  for(x = l; x < r; x = (x + 8) & -8) {
    fillcol(tile, stride, x & 7, t,
            (r & -8) > (x & -8) ? 8 : (r & 7),
            b, c);
    tile += stride;
  }
}

void canvasHline(const TileCanvas *v, int l, int t, int r, int c) {
  if (r < l) {
    int temp = l;
    l = r;
    r = temp;
  }
  canvasRectfill(v, l, t, r, t + 1, c);
}

void canvasVline(const TileCanvas *v, int l, int t, int b, int c) {
  if (b < t) {
    int temp = t;
    t = b;
    b = temp;
  }
  canvasRectfill(v, l, t, l + 1, b, c);
}

void canvasRect(const TileCanvas *v, int l, int t, int r, int b, int c) {
  canvasVline(v, l, t, b, c);
  canvasVline(v, r - 1, t, b, c);
  canvasHline(v, l, t, r, c);
  canvasHline(v, l, b - 1, r, c);
}

void canvasClear(const TileCanvas *w, unsigned int color) {
  size_t nBytes = 32 * w->width * w->height;
  color = (color & 0x000F) * 0x1111;
  dma_memset16(w->chrBase, 0, nBytes);
}

#if 0
void canvasBlitAligned(const TileCanvas *src, const TileCanvas *dst,
                       int srcX, int srcY, int dstX, int dstY,
                       int w, int h) {

  /* Clip in X */
  if (srcX < 0) {
    dstX -= srcX;
    w -= srcX;
    srcX = 0;
  }
  if (dstX < 0) {
    srcX -= dstX;
    w -= dstX;
    dstX = 0;
  }
  if (srcX + w > (int)src->width) {
    w = src->width - srcX;
  }
  if (dstX + w > (int)dst->width) {
    w = dst->width - dstX;
  }
  if (w <= 0) {
    return;
  }

  /* Clip in Y */
  if (srcY < 0) {
    dstY -= srcY;
    h -= srcY;
    srcY = 0;
  }
  if (dstY < 0) {
    srcY -= dstY;
    h -= dstY;
    dstY = 0;
  }
  if (srcY + h > src->height * 8) {
    h = src->height * 8 - srcY;
  }
  if (dstX + w > dst->height * 8) {
    h = dst->height * 8 - dstY;
  }
  if (h < 0) {
    return;
  }

  {
    const uint32_t *srcCol = src->chrBase + srcX * src->height * 8 + srcY;
    uint32_t *dstCol = dst->chrBase + dstX * dst->height * 8 + dstY;
    
    for (; w > 0; --w) {
      for (unsigned int y = 0; y < h; ++y) {
        dstCol[y] = srcCol[y];
      }
      srcCol += src->height * 8;
      dstCol += dst->height * 8;
    }
  }
}
#endif

void canvasInit(const TileCanvas *w, unsigned int color) {
#if ARM9
  NAMETABLE *dst = w->core ? &(MAP_SUB[w->map]) : &(MAP[w->map]);
#else
  NAMETABLE *dst = &(MAP[w->map]);
#endif

  int mapTile = w->mapTileBase;
  for (int x = w->left; x < w->left + w->width; ++x) {
    for (int y = w->top; y < w->top + w->height; ++y) {
      (*dst)[y][x] = mapTile++;
    }
  }
  canvasClear(w, color);
}
