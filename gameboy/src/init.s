;
; Init code for Game Boy
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
include "src/gb.inc"
include "src/global.inc"

; It is not strictly necessary to completely clear the display list,
; as lcd_clear_oam writes a "hide this sprite" value to all unused
; sprites.  But when Options > Exceptions > Unitialized RAM >
; break on read (reset) is on, BGB complains about copying
; uninitialized data to OAM even if said data is provably unused.
; So put "shut BGB up" commands behind a conditional.
bgbcompat equ 1

; Like the NES and Super NES, DMA on the Game Boy takes access to RAM
; and ROM away from the CPU.  But unlike those two, the CPU continues
; to run.  So store a tiny subroutine in HRAM (tightly coupled
; memory) to keep the CPU busy until OAM DMA is done.
section "hram_init", HRAM[$FFF4]
run_dma:: ds 11

; For the purpose of hLocals, see a fairly long rant in global.inc
section "hram_locals", HRAM[hLocals]
  ds locals_size
section "hram_teststate", HRAM[hTestState]
  ds test_state_size

STACK_SIZE EQU 64
section "stack", WRAM0[$D000-STACK_SIZE]
stack_top: ds STACK_SIZE

section "bootregs", WRAM0
initial_a:: ds 1
initial_b:: ds 1

section "rom_init", ROM0
reset_handler::
  di  ; Disable interrupts
  ld sp, stack_top + STACK_SIZE  ; Set up stack pointer (full descending)

  ; A and B used for DMG, SGB, GB Pocket, GBC, or GBA detection.
  ; Useful for motion blur compensation, palette adjustment,
  ; music adjustment on original SGB, etc.
  ; A=01: DMG or SGB
  ; A=FF: Game Boy Pocket or SGB2
  ; A=11, B.0=0: GBC
  ; A=11, B.0=1: GBA
  ld [initial_a], a
  ld c,a
  ld a,b
  ld [initial_b], a

  ; Release the key matrix right now
  ld a,P1F_NONE
  ldh [rP1],a

  ; Initialize controller-related variables so that holding a button
  ; at power-on doesn't produce inconsistent results
  xor a
  ld [cur_keys],a
  ld [das_keys],a
  ld [das_timer],a
  ld [is_sgb],a

  ; To distinguish the SGB models from GB, the game's header must
  ; declare SGB awareness ($0146=$03 and $014B=$33).  Then the game
  ; should send a MLT_REQ command to go to 2-player mode, call
  ; read_pad a few times, and look at bits 1-0 of rP1 after releasing
  ; the key matrix.  These bits are 3 on handhelds; on SGB, they
  ; indicate which controller will be polled by the NEXT call to
  ; read_pad: 3 means player 1, 2 means player 2, and 1 and 0 mean
  ; multitap players 3 and 4.

  ; Because SGB detection takes a few frames, fade out the IPL logo
  ; while it's happening.  Skip it on GBC for two reasons:
  ; GBC+SGB is not authentic hardware, and GBC IPL already faded
  ; out its logo.
  ld b,1
  ld a,c
  cp a,$11
  jr z,.isgbc

  ld a,%00001000  ; bits 3-2: dark gray
  ldh [rBGP],a
  call detect_sgb
  ld a,%00000100  ; bits 3-2: light gray
  ldh [rBGP],a

  ld b,10
.fadelogo:
  call wait_not_vblank
.isgbc:
  call busy_wait_vblank  ; Spin because interrupts are not yet set up
  dec b
  jr nz,.fadelogo

  ; Rendering can be turned off only during blanking.  Fortunately
  ; the fadeout loop left us in vblank.  So set up the video
  ; hardware.  The previous loop left A=0.
  xor a
  ldh [rLCDC], a  ; turn off rendering
  ldh [rSCY], a   ; clear scroll
  ldh [rSCX], a   ; clear scroll
  ldh [rNR52], a  ; disable (and reset) audio

  ; Copy the sprite DMA routine
  ld hl,run_dma_master
  ld de,run_dma
  ld bc,run_dma_end-run_dma_master
  call memcpy

  if bgbcompat
    ; BGB triggers spurious "reading uninitialized WRAM" exceptions
    ; when DMAing the X, tile number, and attribute of an OAM entry
    ; whose Y is offscreen.
    xor a
    ld hl,SOAM
    ld c,160
    call memset_tiny

    ; The VWF engine always modifies the tile overlapping the right
    ; half of a glyph, even if the glyph's opaque area doesn't extend
    ; into that tile.  Occasionally, it may extend one tile past the
    ; 16 tiles (128 pixels, 128 bytes) actually available in the
    ; buffer.  For this reason, I have reserved at least one
    ; additional tile that's never copied to VRAM so that when
    ; drawing overflows, it at least doesn't hurt anything.
    ; But when VWF drawing overflows into this tile, BGB triggers
    ; spurious "reading unitialized WRAM" exceptions.
    ld hl,lineImgBuf
    ld c,136  ; used size plus 8 for the spare tile
    call memset_tiny
  endc

  jp main

;;
; Writes BC bytes of value H starting at DE.
memset::
  ld a, h
  ld [de],a
  inc de
  dec bc
  ld a, b
  or c
  jr nz, memset
  ret

;;
; Copies BC bytes from HL to DE.
memcpy::
  ld a, [hl+]
  ld [de],a
  inc de
  dec bc
  ld a, b
  or c
  jr nz, memcpy
  ret

;;
; The routine gets copied to high RAM
run_dma_master:
  ld a,SOAM >> 8
  ldh [rDMA],a
  ld a,40
.loop:
  dec a
  jr nz,.loop
  ret
run_dma_end:

; If we stuff these in their own sections, RGBLINK might be able to
; pack them between the unused IRQ/RST vectors, at least until we
; figure out which to make into RSTs.

section "memset_tiny",ROM0
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memset_inc",ROM0
;;
; Writes C bytes of value A starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
  ret


