;
; Randum number generator
;
; Written and donated by Sidney Cadot - sidney@ch.twi.tudelft.nl
; 2016-11-07, modified by Brad Smith
;
; May be distributed with the cc65 runtime using the same license:
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
;
; int rand (void);
; void srand (unsigned seed);
;
;  Uses 4-byte state.
;  Multiplier must be 1 (mod 4)
;  Added value must be 1 (mod 2)
;  This guarantees max. period (2**32)
;  The lowest bits have poor entropy and
;  exhibit easily detectable patterns, so
;  only the upper bits 16-22 and 24-31 of the
;  4-byte state are returned.
;
;  The best 8 bits, 24-31 are returned in the
;  low byte A to provide the best entropy in the
;  most commonly used part of the return value.
;

        .export         _rand, _srand

.bss

; The seed. When srand() is not called, the C standard says that that rand()
; should behave as if srand() was called with an argument of 1 before.
rand:   .res 4

.code

_rand:  clc
        lda     rand+0          ; SEED += $B3
        adc     #$B3
        sta     rand+0
        adc     rand+1          ; SEED *= $01010101
        sta     rand+1
        adc     rand+2
        sta     rand+2
        and     #$7f            ; Suppress sign bit (make it positive)
        tax
        lda     rand+2
        adc     rand+3
        sta     rand+3
        rts                     ; return bit (16-22,24-31) in (X,A)

_srand: sta     rand+0          ; Store the seed
        stx     rand+1
        lda     #0
        sta     rand+2          ; Set MSW to zero
        sta     rand+3
        rts

