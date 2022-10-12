;
; Backlight test for 240p test suite
; Copyright 2015 Damian Yerrick
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

.include "nes.inc"
.include "global.inc"
.importzp helpsect_backlight_zone_test

.segment "CODE"
.proc do_backlight
sprite_x = test_state+0
sprite_y = test_state+1
sprite_size = test_state+2
sprite_hide = test_state+3
high_gear = test_state+4
held_keys = test_state+5
invert = test_state+6

  lda #$FD
  sta sprite_size
  lda #128
  sta sprite_x
  sta sprite_y
  asl a
  sta sprite_hide
  sta high_gear
  sta held_keys
  lda #$0F
  sta invert

restart:
  lda #0
  sta PPUMASK
  ldx #$1F
  ldy #$C0
  lda #4
  jsr unpb53_file
  lda #2
  sta OAM+2  ; set the sprite's palette to same as whites of Gus's eyes
  ldx #4
  jsr ppu_clear_oam  ; clear the rest of sprites
loop:
  lda sprite_x
  sta OAM+3
  lda sprite_y
  ora sprite_hide
  sta OAM+0
  lda sprite_size
  sta OAM+1
  jsr ppu_wait_vblank

  ; draw the palette
  ldx #$3F
  stx PPUADDR
  ldy #$00
  sty PPUADDR
  lda invert
  sta PPUDATA
  stx PPUADDR
  ldy #$1B
  sty PPUADDR
  eor #$2F
  sta PPUDATA
  
  ; do not use ppu_screen_on because BG is not used
  lda #OBJ_ON
  sta PPUMASK
  lda #0
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda #VBLANK_NMI|OBJ_1000
  sta PPUCTRL

  lda #helpsect_backlight_zone_test
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_SELECT
  beq :+
    lda #$2F
    eor invert
    sta invert
  :

  lda new_keys+0
  ora held_keys
  sta held_keys
  lda cur_keys
  and #KEY_A
  beq A_not_held

    ; A+direction: change size or speed
    ; (and disable tasks on releasing A until A is repressed)
    lda new_keys
    and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
    beq done_no_A_long

    lda new_keys+0
    and #KEY_UP
    beq not_inc_size
      inc sprite_size
    not_inc_size:
    lda new_keys+0
    and #KEY_DOWN
    beq not_dec_size
      dec sprite_size
    not_dec_size:
    lda sprite_size
    ora #$FC
    sta sprite_size

    lda new_keys+0
    and #KEY_LEFT|KEY_RIGHT
    beq not_toggle_speed
      lda #1
      eor high_gear
      sta high_gear
    not_toggle_speed:

    lda held_keys
    and #<~KEY_A
    sta held_keys
  done_no_A_long:
    jmp done_no_A
  A_not_held:

move_speed = $00

    ; Release A: toggle hidden sprite
    lda held_keys
    and #KEY_A
    beq not_toggle_hide
      eor held_keys
      sta held_keys
      lda #$F0
      eor sprite_hide
      sta sprite_hide
    not_toggle_hide:

    lda high_gear
    beq :+
      lda sprite_size
      and #$03
    :
    tax  ; X = index into one_shl_x for movement speed

    lda cur_keys+0
    and #KEY_RIGHT
    beq not_right
      lda sprite_x
      clc
      adc move_speeds,x
      bcc :+
        lda #255
      :
      sta sprite_x
    not_right:

    lda cur_keys+0
    and #KEY_DOWN
    beq not_down
      lda sprite_y
      clc
      adc move_speeds,x
      bcs down_clamp_y
      cmp #238
      bcc down_have_y
      down_clamp_y:
        lda #238
      down_have_y:
      sta sprite_y
    not_down:

    lda cur_keys+0
    and #KEY_LEFT
    beq not_left
      lda sprite_x
      sec
      sbc move_speeds,x
      bcs :+
        lda #0
      :
      sta sprite_x
    not_left:

    lda cur_keys+0
    and #KEY_UP
    beq not_up
      lda sprite_y
      sec
      sbc move_speeds,x
      bcs :+
        lda #0
      :
      sta sprite_y
    not_up:
  done_no_A:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

.rodata
move_speeds:
  .byte $01, $02, $04, $08
