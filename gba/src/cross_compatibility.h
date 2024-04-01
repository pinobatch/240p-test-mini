#ifndef CROSS_COMPATIBILITY__
#define CROSS_COMPATIBILITY__

#include "useful_qualifiers.h"

#ifdef __GBA__

// GBA defines and all
#include <tonc.h>

#define SCANLINES 0xE4

#define TILE_1D_MAP 0
#define ACTIVATE_SCREEN_HW 0

// write these as macros instead of static inline to make them constexpr
#define RGB5(r, g, b) (((r)<<0) | ((g)<<5) | ((b)<<10))

#endif

#define GBA_SCREEN_WIDTH 240
#define GBA_SCREEN_HEIGHT 192

#define VBLANK_SCANLINES SCREEN_HEIGHT

#endif
