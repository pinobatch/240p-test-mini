;
; Pseudorandom number generator
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
section "rand_ram",WRAM0
randstate: ds 4

section "rand",ROM0

;;
; Generates a pseudorandom 16-bit integer in BC
; using the LCG formula from cc65 rand():
; x[i + 1] = x[i] * 0x01010101 + 0x31415927
; @return A=B=state bits 31-24 (which have the best entropy),
; C=state bits 23-16, DHL trashed
rand::
  ; Load bits 31-8 of the current value to BCA
  ld hl,randstate+3
  ld a,[hl-]
  ld b,a
  ld a,[hl-]
  ld c,a
  ld a,[hl-]  ; skip D; thanks ISSOtm for the idea
  ; Used to load bits 7-0 to E.  Reading [HL] each time turned out
  ; no slower and saved 1 byte.

  ; Multiply by 0x01010101
  add [hl]
  ld d,a
  adc c
  ld c,a
  adc b
  ld b,a

  ; Add 0x31415927 and write back
  ld a,[hl]
  add $27
  ld [hl+],a
  ld a,d
  adc $59
  ld [hl+],a
  ld a,c
  adc $41
  ld [hl+],a
  ld c,a
  ld a,b
  adc $31
  ld [hl],a
  ld b,a
  ret

;;
; Sets the random seed to BC.
; C expects startup code to behave as if srand(1) was called.
; AHL trashed
srand::
  ld hl,randstate+3
  xor a
  ld [hl-],a
  ld [hl-],a
  ld a,b
  ld [hl-],a
  ld [hl],c
  ret

;
; According to tools/rand.py, after srand(1) then ten rand() calls,
; first ten BC results should be
; 3242 2805 8971 25AC F2DD
; 0E2B BBBD 66BB A14A 2493
