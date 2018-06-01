;
; Binary to decimal (8-bit)
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
section "bcd",ROM0

bcd8bit_iter: macro
  cp \1
  jr c,.nope\@
  sub \1
.nope\@:
  rl b
  endm

;;
; Converts an 8-bit value to decimal.
; @param A the value
; @return A: hundreds and tens digits; C: ones digit;
; DEHL: unchanged; Z set if number is less than 10
bcd8bit::
  bcd8bit_iter 200
  bcd8bit_iter 100
  bcd8bit_iter 80
  bcd8bit_iter 40
  bcd8bit_iter 20
  bcd8bit_iter 10
  ld c,a
  ld a,b
  cpl  ; correct for 8080 use of borrow flag instead of carry
  and $3F
  ret
