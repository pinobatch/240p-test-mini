;
; Rant about entirely EQU-free code
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
  IF  !DEF(GLOBAL_INC)
GLOBAL_INC SET 1

; This program contains one use of EQU to allocate local variables
; in RAM.  Other more experienced devs want to abolish allocation
; of variables using EQU.  Without EQU, I can't see how to make
; different subroutines share RAM for their local variables without
; using UNION.

; The person who suggested using UNION has not yet explained how to
; resolve its drawback that the declaration of local variables is
; separated from the subroutine's code.  Either you have to declare
; local variables for all subroutines in a program within one file:
;
; UNION
; draw_metasprite__basex: ds 1
; draw_metasprite__basey: ds 1
; draw_metasprite__width: ds 1
; draw_metasprite__height: ds 1
; NEXTU
; mul8__factor1: .ds 1
; mul8__factor2: .ds 1
; mul8__product: .ds 2
; ENDU
;
; Or you have to declare the local variables for every subroutine
; in a separate file:
;
; UNION
; INCLUDE "src/draw_sprite_vars.inc"
; NEXTU
; INCLUDE "src/mul8_vars.inc"
; ENDU
;
; The interim solution uses a single EQU to set up RSSET.
;
; RSSET hLocals
; Lbasex rb 1
; Lbasey rb 1
; Lwidth rb 1
; Lheight rb 1
;
; RSSET hLocals
; Lfactor1 rb 1
; Lfactor2 rb 1
; Lproduct rw 1
;
; Follow this thread:
; http://gbdev.gg8.se/forums/viewtopic.php?pid=3176#p3176
hLocals EQU $FF80
locals_size EQU 16
hTestState EQU $FF90
test_state_size EQU 16

; RGBASM requires that RST arguments be constexpr, not imported
memset_tiny     EQU $0008
wait_vblank_irq EQU $0010

; Arguments for draw_spriterect
  rsset hLocals
Lspriterect_y          rb 1
Lspriterect_x          rb 1
Lspriterect_tile       rb 1
Lspriterect_attr       rb 1
Lspriterect_height     rb 1
Lspriterect_width      rb 1
Lspriterect_rowht      rb 1
Lspriterect_tilestride rb 1

; People keep calling an LR35902 a "GBZ80".  It's closer to "8080
; plus prefix CB from Z80".
djnz: macro
    dec b
    jr nz,\1
    endm

  ENDC
