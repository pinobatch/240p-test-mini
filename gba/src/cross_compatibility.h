#ifndef CROSS_COMPATIBILITY__
#define CROSS_COMPATIBILITY__

#include "asm_swi_defs.h"

#ifdef __GBA__

// GBA defines and all
#include <gba.h>
#include "useful_qualifiers.h"
#define SCANLINES 0xE4
#define ROM 0x8000000
ALWAYS_INLINE MAX_OPTIMIZE void __set_next_vcount_interrupt_gba(int scanline) {
    REG_DISPSTAT  = (REG_DISPSTAT & 0xFF) | (scanline<<8);
}
ALWAYS_INLINE MAX_OPTIMIZE int __get_next_vcount_interrupt(void) {
    u16 reg_val = REG_DISPSTAT;
    return reg_val >> 8;
}
#define __set_next_vcount_interrupt(x) __set_next_vcount_interrupt_gba(x)
#define SCANLINE_IRQ_BIT LCDC_VCNT
#define REG_WAITCNT *(vu16*)(REG_BASE + 0x204) // Wait state Control
#define SRAM_READING_VALID_WAITCYCLES 3
#define SRAM_ACCESS_CYCLES 9
#define NON_SRAM_MASK 0xFFFC
#define BASE_WAITCNT_VAL 0x4314
#define OVRAM_START ((uintptr_t)OBJ_BASE_ADR)
#define TILE_1D_MAP 0
#define ACTIVATE_SCREEN_HW 0
#define EWRAM_SIZE 0x0003FF40
#define VRAM_0 VRAM
#define HAS_SIO
#define CLOCK_SPEED 16777216
#define SAME_ON_BOTH_SCREENS 0
#define CONSOLE_LETTER 'G'

#define HAS_SOUND_ACCESS
typedef u16 PATRAM_DATA[16];
typedef u32 SPRITERAM_DATA[8];

#endif

#ifdef __NDS__

// NDS defines and all
#include <nds.h>
#include "useful_qualifiers.h"
#include "decompress.h"
#define SCANLINES 0x107
#define ROM GBAROM
ALWAYS_INLINE MAX_OPTIMIZE int __get_next_vcount_interrupt(void) {
    u16 reg_val = REG_DISPSTAT;
    return (reg_val >> 8) | ((reg_val & 0x80) << 1);
}
ALWAYS_INLINE MAX_OPTIMIZE void __reset_vcount(void) {
    REG_VCOUNT = (REG_VCOUNT & 0xFE00) | (SCANLINES - 6);
}
#define __set_next_vcount_interrupt(x) SetYtrigger(x)
#define SCANLINE_IRQ_BIT DISP_YTRIGGER_IRQ
#define REG_WAITCNT REG_EXMEMCNT // Wait state Control
#define SRAM_READING_VALID_WAITCYCLES 3
#define SRAM_ACCESS_CYCLES (2 * 18)
#define NON_SRAM_MASK 0xFFFC
#define BASE_WAITCNT_VAL 0x0014
#define OVRAM_START ((uintptr_t)SPRITE_GFX)
#define OVRAM_START_SUB ((uintptr_t)SPRITE_GFX_SUB)
#define OBJ_ON DISPLAY_SPR_ACTIVE
#define OBJ_1D_MAP (1<<6)
#define TILE_1D_MAP (1<<4)
#define ACTIVATE_SCREEN_HW (1<<16)
#define EWRAM 0x2000000
#define EWRAM_SIZE 0x00400000
#define VRAM_0_SUB BG_GFX_SUB
#define ARM9_CLOCK_SPEED 67108864
#define ARM7_CLOCK_SPEED 33554432
#define ARM7_GBA_CLOCK_SPEED 16777216
#define CLOCK_SPEED ARM9_CLOCK_SPEED
#define SAME_ON_BOTH_SCREENS 1
#define CONSOLE_LETTER 'D'

// Define OBJATTR struct back
typedef struct {
    u16 attr0;
    u16 attr1;
    u16 attr2;
    u16 dummy;
} ALIGN(4) OBJATTR;

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
typedef struct {
	u16 SrcNum;				// Source Data Byte Size
	u8  SrcBitNum;			// 1 Source Data Bit Number
	u8  DestBitNum;			// 1 Destination Data Bit Number
	u32 DestOffset:31;		// Number added to Source Data
	u32 DestOffset0_On:1;	// Flag to add/not add Offset to 0 Data
} BUP;

// GBA Video stuff that should be applied to NDS

typedef u16 PATRAM_DATA[16];
typedef u32 SPRITERAM_DATA[8];
#define PATRAM4(x, tn) ((u32 *)(((uintptr_t)VRAM_0) | (((x) << 14) + ((tn) << 5)) ))
#define PATRAM4_SUB(x, tn) ((u32 *)(((uintptr_t)VRAM_0_SUB) | (((x) << 14) + ((tn) << 5)) ))
#define SPR_VRAM(tn) ((u32 *)((OVRAM_START) | ((tn) << 5)))
#define SPR_VRAM_SUB(tn) ((u32 *)((OVRAM_START_SUB) | ((tn) << 5)))
typedef u16 NAMETABLE[32][32];
#define MAP ((NAMETABLE *)VRAM_0)
#define MAP_SUB ((NAMETABLE *)VRAM_0_SUB)
#define	CHAR_BASE(m)		((m) << 2)
#define SCREEN_BASE(m)		((m) << 8)
#define LCDC_OFF (1 << 7)
#define MODE_0 MODE_0_2D
#define MODE_1 MODE_1_2D
#define WIN0_ON DISPLAY_WIN0_ON
#define WIN1_ON DISPLAY_WIN1_ON

// GBA BG stuff that should be applied to NDS

#define BG_16_COLOR BG_COLOR_16
#define BG_256_COLOR BG_COLOR_256
#define BG_SIZE(m) ((m<<14))
#define BG_WID_32 BG_SIZE(0)
#define BG_WID_64 BG_SIZE(1)
#define BG_HT_32  BG_SIZE(0)
#define BG_HT_64  BG_SIZE(2)

#define BG0_ON DISPLAY_BG0_ACTIVE
#define BG1_ON DISPLAY_BG1_ACTIVE

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
#define DMA16 DMA_16_BIT
#define DMA32 DMA_32_BIT
#define DMA_HBLANK DMA_START_HBL
#define DMA_VBLANK DMA_START_VBL
#define DMA_SRC_FIXED DMA_SRC_FIX
#define DMA_DST_FIXED DMA_DST_FIX

#define DMA_Copy(channel, source, dest, mode) {\
	REG_DMA##channel##SAD = (u32)(source);\
	REG_DMA##channel##DAD = (u32)(dest);\
	REG_DMA##channel##CNT = DMA_ENABLE | (mode); \
}

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
