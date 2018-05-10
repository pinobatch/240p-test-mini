;
; Hardware includes for Game Boy
;
; Copyright 2018 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;


  IF  !DEF(GB_INC)
GB_INC SET 1

; hardware.inc comes from
; https://github.com/tobiasvl/hardware.inc/blob/master/hardware.inc
INCLUDE "src/hardware.inc"

; RAM areas ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; VRAM on the Game Boy consists of three 2K banks of CHR RAM and
; two 1K nametables.
CHRRAM0 EQU $8000  ; Sprite tiles 0-127; BG tiles 0-127 if BG_CHR01 on
CHRRAM1 EQU $8800  ; Sprite and BG tiles 128-255
CHRRAM2 EQU $9000  ; BG tiles 0-127 if BG_CHR01 off
RAM_END EQU $DFFF

; Controller ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; See rP1, PADB_*, and PADF_* in hardware.inc

P1F_NONE     EQU $30
P1F_BUTTONS  EQU $10
P1F_DPAD     EQU $20

; Serial port ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This will be filled in when someone solders me an NES controller
; to Game Link cable.

; Audio ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; See rNR* in hardware.inc

; LCD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; See rLCDC, rSTAT, rDMA, rSCX, rSCY, rWX, rWY, rDMA in hardware.inc

; 76543210
; |||||||+- Render BG
; ||||||+-- Render sprites
; |||||+--- 0: Sprites 8x8; 1: Sprites 8x16
; ||||+---- 0: Main BG uses BGMAP0; 1: Main BG uses BGMAP1
; |||+----- 0: BG uses CHRRAM2 and CHRRAM1; 1: BG uses CHRRAM0 and CHRRAM1
; ||+------ Enable window
; |+------- 0: Window uses BGMAP0; 1: Window uses BGMAP1
; +-------- LCD onrLCDC         EQU $FF40
OBJ_ON       EQU $02
OBJ_8X16     EQU $06
BG_NT0       EQU $01
BG_NT1       EQU $09
BG_CHR21     EQU $00
BG_CHR01     EQU $10
WINDOW_NT0   EQU $20
WINDOW_NT1   EQU $60

; 76543210
;  |||||++- (RO) 0: hblank; 1: vblank; 3: OAM scan; 3: active
;  ||||+--- (RO) 1: rLYC equals rLY right now
;  |||+---- (RW) 1: assert rSTAT interrupt during hblank
;  ||+----- (RW) 1: assert rSTAT interrupt during vblank
;  |+------ (RW) 1: assert rSTAT interrupt during OAM scan
;  +------- (RW) 1: assert rSTAT interrupt during rLYC match
STAT_MODE     EQU $03
STAT_HBLANK   EQU $00
STAT_VBLANK   EQU $01
STAT_OAM      EQU $02
STAT_ACTIVE   EQU $03
STAT_LYC      EQU $04
STAT_HIRQ     EQU $08
STAT_VIRQ     EQU $10
STAT_OAMIRQ   EQU $20
STAT_LYCIRQ   EQU $40

; Writing M to rDMA triggers immediate 160 byte copy of a display
; list from M<<8 to OAM at $FE00.  CPU must be running in HRAM.

BOAM_BGP1  EQU 4
BOAM_HFLIP EQU 5
BOAM_VFLIP EQU 6
BOAM_BACK  EQU 7

; 76543210
; ||||||++- backdrop (3: black, 2: dark gray, 1: light gray, 0: white)
; ||||++--- color 1
; ||++----- color 2
; ++------- color 3

; Interrupts ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; See rIE, rIF in hardware.inc

; 76543210  Which events cause an interrupt
;    ||||+- 1: CALL $40 on vblank
;    |||+-- 1: CALL $48 on rSTAT
;    ||+--- 1: CALL $50 on timer
;    |+---- 1: CALL $58 on Game Link byte completion
;    +----- 1: CALL $60 on keypress

; ROM header ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SGB_NONE EQU $00
SGB_SUPPORT EQU $03
REGION_J EQU $00
REGION_UE EQU $01

; Mapper ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; MBC1 names per
; https://gekkio.fi/files/gb-docs/gbctr.pdf

; Lower nibble = $A enables RAM if present; others disable
rMBC1RAM_EN = $0000
MBC1_SRAM_OFF EQU $00
MBC1_SRAM_ON  EQU $0A

; $2000: Select 16 KiB ROM bank at $4000-$7FFF
; ($00 treated as $01)
rMBC1BANK1 = $2000

; $4000: Select 8 KiB ROM bank at $A000, or 512 KiB PRG ROM outer bank
rMBC1BANK2 = $4000

; $6000: 1 to apply $4000 setting to fixed ROM bank at $0000-$3FFF
; (for multicarts) and SRAM at $A000-$BFFF, or 0 to fix bank 0 in
; those regions.  Big ROM commonly uses $00 and SRAM bank 0; big SRAM
; commonly uses $01 and the first 32 PRG ROM banks.
rMBC1MODE = $6000
MBC1_BIG_ROM   EQU $00
MBC1_BIG_RAM   EQU $01

  ENDC