;
; Hardware include addemda for Game Boy
;
; Copyright 2018, 2022 Damian Yerrick
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
GB_INC = 1

; hardware.inc comes from
; https://github.com/gbdev/hardware.inc/blob/master/hardware.inc
INCLUDE "src/hardware.inc"

; VRAM on the Game Boy consists of three 2K banks of CHR RAM and
; two 1K nametables.
CHRRAM0 EQU $8000  ; Sprite tiles 0-127; BG tiles 0-127 if BG_CHR01 on
CHRRAM1 EQU $8800  ; Sprite and BG tiles 128-255
CHRRAM2 EQU $9000  ; BG tiles 0-127 if BG_CHR01 off

; Common combinations of LCDC flags
OBJ_ON       EQU LCDCF_OBJON
OBJ_8X16     EQU LCDCF_OBJON|LCDCF_OBJ16
BG_NT0       EQU LCDCF_BGON|LCDCF_BG9800
BG_NT1       EQU LCDCF_BGON|LCDCF_BG9C00
BG_CHR21     EQU LCDCF_BG8800
BG_CHR01     EQU LCDCF_BG8000
WINDOW_NT0   EQU LCDCF_WINON|LCDCF_WIN9800
WINDOW_NT1   EQU LCDCF_WINON|LCDCF_WIN9C00

; Palette ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down. 
drgb: macro
  dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
  endm

  ENDC
