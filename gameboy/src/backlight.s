;
; Backlight zone test for 240p test suite
; Copyright 2018 Damian Yerrick
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;
include "src/gb.inc"
include "src/global.inc"

  rsset hTestState
xpos rb 1
ypos rb 1
curpalette rb 1
held_keys rb 1
is_hidden rb 1
cursize rb 1

section "backlight",ROM0,align[4]
backlight_chr:
  incbin "obj/gb/backlightzone.chrgb.pb16"

activity_backlight_zone::
  ld a,88
  ldh [xpos],a
  ldh [ypos],a
  xor a
  ldh [is_hidden],a
  ldh [cursize],a
  dec a
  ldh [curpalette],a
  
.restart:
  call lcd_off
  xor a
  ldh [held_keys],a
  ld [help_bg_loaded],a

  ; Clear nametable
  ld h,a
  ld de,_SCRN0
  ld bc,32*18
  call memset

  ; Clear unused sprites
  ld a,4
  ld [oam_used],a
  call lcd_clear_oam

  ; Load pattern table
  ld hl,CHRRAM0
  ld de,backlight_chr
  ld b,4
  call pb16_unpack_block

  ld a,LCDCF_ON|BG_NT0|BG_CHR21|OBJ_ON
  ld [vblank_lcdc_value],a
  ldh [rLCDC],a
  xor a
  ldh [rBGP],a   ; blank screen (GB)
  ldh [rOBP0],a
  dec a
  ldh [rLYC],a  ; disable lyc irq

.loop:
  ld b,helpsect_backlight_zone_test
  call read_pad_help_check
  jr nz,.restart

  ; Process input
  ld a,[new_keys]
  ld b,a
  ldh a,[held_keys]
  or b
  ldh [held_keys],a

  ld a,[cur_keys]
  ld b,a
  bit PADB_A,b
  jr z,.not_A

    ; A+Up/Down: Change size
    ld a,[new_keys]
    and PADF_UP|PADF_DOWN
    jr z,.size_unchanged
      ld b,a
      ldh a,[cursize]
      bit PADB_UP,b
      jr z,.not_size_up
        inc a
      .not_size_up:
      bit PADB_DOWN,b
      jr z,.not_size_down
        dec a
      .not_size_down:
      and $03
      ldh [cursize],a

      ; If a size key was pressed, cancel releasing A to
      ; hide/show
      ld hl,held_keys
      res PADB_A,[hl]
    .size_unchanged:
    jr .done_A

  .not_A:
    ; B: held keys
    ldh a,[xpos]
    bit PADB_LEFT,b
    jr z,.not_left
      dec a
      cp 8
      jr c,.not_left
      ldh [xpos],a
    .not_left:
    bit PADB_RIGHT,b
    jr z,.not_right
      inc a
      cp 168
      jr nc,.not_right
      ldh [xpos],a
    .not_right:

    ldh a,[ypos]
    bit PADB_UP,b
    jr z,.not_up
      dec a
      cp 16
      jr c,.not_up
      ldh [ypos],a
    .not_up:
    bit PADB_DOWN,b
    jr z,.not_down
      inc a
      cp 160
      jr nc,.not_down
      ldh [ypos],a
    .not_down:
  
    ; Release A: Invert
    ldh a,[held_keys]
    and PADF_A
    jr z,.no_release_A
      ldh a,[is_hidden]
      cpl
      ldh [is_hidden],a
      xor a
      ldh [held_keys],a
    .no_release_A:
  .done_A:

  ld a,[new_keys]
  bit PADB_B,a
  ret nz
  bit PADB_SELECT,a
  jr z,.not_select
    ldh a,[curpalette]
    cpl
    ldh [curpalette],a
  .not_select:

  ; Move sprite
  ld hl,SOAM
  ldh a,[ypos]
  ld b,a
  ld a,[is_hidden]
  or b
  ld [hl+],a  ; 0: Y position
  ldh a,[xpos]
  ld [hl+],a  ; 1: X position
  ldh a,[cursize]
  ld [hl+],a  ; 2: Tile
  xor a
  ld [hl+],a  ; 3: Palette and flip

  call wait_vblank_irq
  call run_dma
  ldh a,[curpalette]
  ldh [rBGP],a
  cpl
  ldh [rOBP0],a

  jp .loop

