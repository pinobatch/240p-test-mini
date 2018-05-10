;
; Digram tree encoding (DTE) text decompression for Game Boy
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
include "src/global.inc"

DTE_STACK_SIZE equ 8
DTE_MIN_CODEUNIT equ 136
MIN_PRINTABLE equ 32

section "dtestack",WRAM0,align[3]
dtestack: ds DTE_STACK_SIZE

section "undte",ROM0

;;
; Decompresses DTE text from HL to DE.
; Stops at the first code unit less than MIN_PRINTABLE.
; @param HL source address
; @param DE destination address
; @return HL after a control character in src;
; DE at a control character in dst;
; A = ending control character
undte_line::
  ld bc,dtestack

.charloop:
  ; If there's a code on the stack, print it
  ld a,c
  xor low(dtestack)
  jr z,.stack_empty
  dec bc
  ld a,[bc]
  jr .print_code_a
.stack_empty:
  ; Otherwise, retrieve a code from the compressed text
  ld a,[hl+]
.print_code_a:
  ; If not a pair, save it to the string
  cp DTE_MIN_CODEUNIT
  jr nc,.code_is_pair
  ld [de],a
  ; If not a control, advance to the next code
  cp MIN_PRINTABLE
  ret c
  inc de
  jr .charloop

.code_is_pair:
  push hl
  ; For a pair, we want to push the second code to dtestack
  ; and then decode the first.  The address of the second is
  ; dte_replacements + 2*(code - DTE_MIN_CODEUNIT) + 1
  sub DTE_MIN_CODEUNIT
  ld hl,dte_replacements
  scf
  adc a  ; A = 2*(code - DTE_MIN_CODEUNIT) + 1
  add l
  ld l,a
  jr nc,.pairtable_no_wrap
  inc h
.pairtable_no_wrap:
  ; Get the second code and stack it
  ld a,[hl-]
  ld [bc],a
  inc bc

  ; Now get the first code and print it
  ld a,[hl]
  pop hl
  jr .print_code_a
