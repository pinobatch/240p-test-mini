;
; PB16 decompression for Game Boy
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

  rsset hLocals
pb16_byte0 rb 1

section "pb16", ROM0

; The PB16 format is a starting point toward efficient RLE image
; codecs on Game Boy and Super NES.
;
; 0: Load a literal byte
; 1: Repeat from 2 bytes ago

pb16_unpack_packet:
  ; Read first bit of control byte.  Treat B as a ring counter with
  ; a 1 bit as the sentinel.  Once the 1 bit reaches carry, B will
  ; become 0, meaning the 8-byte packet is complete.
  ld a,[de]
  inc de
  scf
  rla
  ld b,a
.byteloop:
  ; If the bit from the control byte is clear, plane 0 is is literal
  jr nc,.p0_is_literal
  ldh a,[pb16_byte0]
  jr .have_p0
.p0_is_literal:
  ld a,[de]
  inc de
  ldh [pb16_byte0],a
.have_p0:
  ld [hl+],a

  ; Read next bit.  If it's clear, plane 1 is is literal.
  ld a,c
  sla b
  jr c,.have_p1
.p1_is_copy:
  ld a,[de]
  inc de
  ld c,a
.have_p1:
  ld [hl+],a

  ; Read next bit of control byte
  sla b
  jr nz,.byteloop
  ret

;;
; Unpacks 2*B packets from DE to HL, producing 8 bytes per packet.
; About 127 cycles (2 scanlines) per 8-byte packet; filling CHR RAM
; thus takes (6144/8)*127 = about 97536 cycles or 93 ms
pb16_unpack_block::
  ; Prefill with zeroes
  xor a
  ldh [pb16_byte0],a
  ld c,a
.packetloop:
  push bc
  call pb16_unpack_packet
  call pb16_unpack_packet
  ld a,c
  pop bc
  ld c,a
  dec b
  jr nz,.packetloop
  ret
