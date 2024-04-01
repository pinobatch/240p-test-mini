#ifndef CROSS_COMPATIBILITY__
#define CROSS_COMPATIBILITY__

#ifdef __GBA__

// GBA defines and all
#include <tonc.h>
#include "useful_qualifiers.h"

#define SCANLINES 0xE4

#define TILE_1D_MAP 0
#define ACTIVATE_SCREEN_HW 0

// write these as macros instead of static inline to make them constexpr
#define RGB5(r, g, b) (((r)<<0) | ((g)<<5) | ((b)<<10))

#endif

#ifdef __NDS__

// NDS defines and all
#include <nds.h>
#include "useful_qualifiers.h"
#include "decompress.h"
#define SCANLINES 0x107

ALWAYS_INLINE MAX_OPTIMIZE void __reset_vcount(void) {
    REG_VCOUNT = (REG_VCOUNT & 0xFE00) | (SCANLINES - 6);
}

#define VRAM_0_SUB BG_GFX_SUB
#define SAME_ON_BOTH_SCREENS 1

// Define SWIs back
#define Div(x, y) swiDivide(x, y)
#define DivMod(x, y) swiRemainder(x, y)
#define Sqrt(x) swiSqrt(x)
#define LZ77UnCompVram(x, y) swi_LZ77UnCompWrite16bit((const void*)x, (void*)y)
#define RLUnCompVram(x, y) decompress((const void*)x, (void*)y, RLEVram)
#define CpuFastSet(x, y, z) swiFastCopy(x, y, z)
#define VBlankIntrWait() swiWaitForVBlank()
#define Halt() CP15_WaitForInterrupt()
#define BitUnPack(x, y, z) swiUnpackBits(x, y, z)

// Define BUP struct back
typedef struct BUP
{
    u16 src_len;	//!< source length (bytes)	
    u8 src_bpp;		//!< source bitdepth (1,2,4,8)
    u8 dst_bpp;		//!< destination bitdepth (1,2,4,8,16,32)
    u32 dst_ofs;	//!< {0-30}: added offset {31}: zero-data offset flag
} BUP;

// GBA Video stuff that should be applied to NDS

// Define OBJ_ATTR struct back
typedef struct {
    u16 attr0;
    u16 attr1;
    u16 attr2;
    u16 dummy;
} ALIGN(4) OBJ_ATTR;

typedef struct { u32 data[8];  } TILE, TILE4;
typedef struct { u32 data[16]; } TILE8;
typedef TILE CHARBLOCK[512];
typedef TILE8 CHARBLOCK8[256];
typedef u16 SCREENMAT[32][32];
typedef struct POINT16 { s16 x, y; } ALIGNED(4) POINT16, BG_POINT;

#define tile_mem ((CHARBLOCK*)VRAM_0)
#define tile_mem_sub ((CHARBLOCK*)VRAM_0_SUB)
#define tile_mem_obj ((CHARBLOCK*)SPRITE_GFX)
#define tile_mem_obj_sub ((CHARBLOCK*)SPRITE_GFX_SUB)
#define se_mat ((SCREENMAT*)VRAM_0)
#define se_mat_sub ((SCREENMAT*)VRAM_0_SUB)
#define pal_bg_mem BG_PALETTE
#define pal_bg_mem_sub BG_PALETTE_SUB
#define pal_obj_mem SPRITE_PALETTE
#define pal_obj_mem_sub SPRITE_PALETTE_SUB
#define oam_mem ((OBJ_ATTR*)OAM)
#define oam_mem_sub ((OBJ_ATTR*)OAM_SUB)

#define DCNT_MODE0 MODE_0_2D
#define DCNT_MODE1 MODE_1_2D
#define DCNT_WIN0 DISPLAY_WIN0_ON
#define DCNT_WIN1 DISPLAY_WIN1_ON
#define DCNT_BG0 DISPLAY_BG0_ACTIVE
#define DCNT_BG1 DISPLAY_BG1_ACTIVE
#define DCNT_OBJ DISPLAY_SPR_ACTIVE
#define DCNT_OBJ_1D (1<<6)
#define DCNT_BLANK DISPLAY_SCREEN_OFF
#define TILE_1D_MAP (1<<4)
#define ACTIVATE_SCREEN_HW (1<<16)

// GBA BG stuff that should be applied to NDS

#define REG_BGCNT BGCTRL	//!< Bg control array
#define REG_BGCNT_SUB BGCTRL_SUB	//!< Bg control array

#define REG_BG_OFS ((volatile BG_POINT*)REG_BGOFFSETS)	//!< Bg scroll array
#define REG_BG_OFS_SUB ((volatile BG_POINT*)REG_BGOFFSETS_SUB)	//!< Bg scroll array
#define	BG_CBB(m) ((m) << 2)
#define	BG_SBB(m) ((m) << 8)
#define BG_4BPP BG_COLOR_16
#define BG_8BPP BG_COLOR_256
#define BG_SIZE(m) ((m<<14))
#define BG_SIZE0 BG_SIZE(0)
#define BG_SIZE1 BG_SIZE(1)
#define BG_SIZE2 BG_SIZE(2)

// GBA Sprite stuff that should be applied to NDS

#define ATTR0_HIDE ATTR0_DISABLED
#define ATTR1_HFLIP ATTR1_FLIP_X
#define ATTR1_VFLIP ATTR1_FLIP_Y
#define ATTR0_Y(m) OBJ_Y(m)
#define ATTR1_X(m) OBJ_X(m)
#define ATTR0_4BPP ATTR0_COLOR_16
#define ATTR2_PALBANK(m) ATTR2_PALETTE(m)

// GBA Window stuff that should be applied to NDS

#define	REG_WIN0H	*((vu16 *)(&WIN0_X1))
#define	REG_WIN1H	*((vu16 *)(&WIN1_X1))
#define	REG_WIN0V	*((vu16 *)(&WIN0_Y1))
#define	REG_WIN1V	*((vu16 *)(&WIN1_Y1))
#define	REG_WININ	WIN_IN
#define	REG_WINOUT	WIN_OUT
#define	REG_WIN0H_SUB	*((vu16 *)(&SUB_WIN0_X1))
#define	REG_WIN1H_SUB	*((vu16 *)(&SUB_WIN1_X1))
#define	REG_WIN0V_SUB	*((vu16 *)(&SUB_WIN0_Y1))
#define	REG_WIN1V_SUB	*((vu16 *)(&SUB_WIN1_Y1))
#define	REG_WININ_SUB	SUB_WIN_IN
#define	REG_WINOUT_SUB	SUB_WIN_OUT

// GBA DMA stuff that should be applied to NDS

#define REG_DMA0SAD DMA0_SRC
#define REG_DMA0DAD DMA0_DEST
#define REG_DMA0CNT DMA0_CR
#define REG_DMA1SAD DMA1_SRC
#define REG_DMA1DAD DMA1_DEST
#define REG_DMA1CNT DMA1_CR
#define REG_DMA2SAD DMA2_SRC
#define REG_DMA2DAD DMA2_DEST
#define REG_DMA2CNT DMA2_CR
#define REG_DMA3SAD DMA3_SRC
#define REG_DMA3DAD DMA3_DEST
#define REG_DMA3CNT DMA3_CR

#define DMA_DST_RELOAD DMA_DST_FIX
#define DMA_16 DMA_16_BIT
#define DMA_32 DMA_32_BIT
#define DMA_AT_HBLANK DMA_START_HBL
#define DMA_AT_VBLANK DMA_START_VBL
#define DMA_SRC_FIXED DMA_SRC_FIX
#define DMA_DST_FIXED DMA_DST_FIX

#define DMA_Copy(channel, source, dest, mode) {\
	REG_DMA##channel##SAD = (u32)(source);\
	REG_DMA##channel##DAD = (u32)(dest);\
	REG_DMA##channel##CNT = DMA_ENABLE | (mode); \
}

// GBA memset/memcpy stuff that should be applied to NDS
void memset16(void *dst, unsigned short c, size_t length_words);
#define tonccpy(dst, src, size) swiCopy(src, dst, size >> 1)

// GBA Timer stuff that should be applied to NDS

#define REG_TM0CNT_L TIMER0_DATA
#define REG_TM0CNT_H TIMER0_CR
#define REG_TM1CNT_L TIMER1_DATA
#define REG_TM1CNT_H TIMER1_CR

#define	TIMER_COUNT	TIMER_CASCADE
#define	TIMER_START	TIMER_ENABLE

#endif

#define GBA_SCREEN_WIDTH 240
#define GBA_SCREEN_HEIGHT 192

#define VBLANK_SCANLINES SCREEN_HEIGHT

#endif
