;
; Scrolling tests for 240p test suite
; Copyright 2015-2016 Damian Yerrick
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
.include "rectfill.inc"
.importzp helpsect_grid_scroll_test, helpsect_hill_zone_scroll_test
GRID_SCROLL_TILE = $0D

.segment "CODE"
.proc do_grid_scroll
direction = test_state+0
speed     = test_state+1
running   = test_state+2
arelease  = test_state+3
xpos      = test_state+4
ypos      = test_state+5
  lda #KEY_RIGHT
  sta direction
  sta speed
  sta running
restart:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette
  lda #GRID_SCROLL_TILE
  ldy #$00
  sty arelease
  ldx #$20
  jsr ppu_clear_nt
  ldx #$2C
  jsr ppu_clear_nt
loop:

  lda running
  beq not_running
  lda direction
  sta 0

  lsr 0
  bcc not_running_right
    lda xpos
    clc
    adc speed
    sta xpos
    jmp not_running
  not_running_right:
  lsr 0
  bcc not_running_left
    lda xpos
    sbc speed
    sta xpos
    jmp not_running
  not_running_left:
  lsr 0
  bcc not_running_down
    lda ypos
    clc
    adc speed
    sta ypos
    jmp not_running
  not_running_down:
  lsr 0
  bcc not_running_up
    lda ypos
    sbc speed
    sta ypos
    jmp not_running
  not_running_up:
  not_running:

  jsr ppu_wait_vblank
  lda xpos
  and #$07
  tax
  lda ypos
  and #$07
  tay
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on

  lda #helpsect_grid_scroll_test
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda new_keys+0
  and #KEY_A
  ora arelease
  sta arelease

  ; Release A: Toggle running
  lda cur_keys+0
  eor #$FF
  and arelease
  beq :+
    lda #1
    eor running
    sta running
    lda #0
    sta arelease
  :

  lda cur_keys+0
  and #KEY_A
  beq not_dir_change
    ; Hold A and press a direction to set the scroll direction
    lda new_keys+0
    and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
    beq dir_speed_change_done
    sta direction
    lda #0
    sta arelease
    beq dir_speed_change_done
  not_dir_change:
  lda new_keys+0
  and #KEY_UP
  beq notIncSpeed
    lda speed
    cmp #4
    bcs notIncSpeed
    inc speed
    bcc dir_speed_change_done
  notIncSpeed:
  lda new_keys+0
  and #KEY_DOWN
  beq notDecSpeed
    lda speed
    cmp #2
    bcc notDecSpeed
    dec speed
    bcc dir_speed_change_done
  notDecSpeed:

  dir_speed_change_done:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

; Green Hill Zone ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hill_zone_lastfinex = test_state + 11

hill_zone_xlo = test_state + 12
hill_zone_xhi = test_state + 13
hill_zone_speed = test_state + 14
hill_zone_dir = test_state + 15
.proc do_hill_zone_scroll

  lda #1
  sta hill_zone_speed
  lsr a
  sta hill_zone_dir
  sta hill_zone_xlo
  sta hill_zone_xhi

restart:
  jsr hill_zone_load
loop:

  jsr ppu_wait_vblank
  ldy #0
  sty OAMADDR
  lda #>OAM
  sta OAM_DMA
  ldx #0
  lda #VBLANK_NMI|BG_0000|OBJ_1000
  sec
  jsr ppu_screen_on
  jsr hill_zone_do_raster

  lda #helpsect_hill_zone_scroll_test
  jsr read_pads_helpcheck
  bcs restart
  jsr hill_zone_speed_control

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

.proc hill_zone_speed_control
  lda new_keys+0
  and #KEY_A
  eor hill_zone_dir
  sta hill_zone_dir

  lda new_keys+0
  and #KEY_UP
  beq not_up
    lda hill_zone_speed
    cmp #16
    bcs not_up
    inc hill_zone_speed
  not_up:

  lda new_keys+0
  and #KEY_DOWN
  beq not_down
    lda hill_zone_speed
    cmp #2
    bcc not_down
    dec hill_zone_speed
  not_down:

  lda new_keys+0
  and #KEY_LEFT|KEY_RIGHT
  beq not_leftright
    lda #1
    eor hill_zone_dir
    sta hill_zone_dir
  not_leftright:

  lda hill_zone_speed
  ldx hill_zone_dir
  bmi nomove
  cpx #1
  bcc :+
    eor #$FF
    dec hill_zone_xhi
  :
  adc hill_zone_xlo
  sta hill_zone_xlo
  bcc :+
    inc hill_zone_xhi
  :
nomove:
  rts
.endproc

.proc hill_zone_load
  lda #$01
  jsr load_sb53_file

  ; ensure last tile is nontransparent
  lda #$1F
  sta PPUADDR
  ldx #$F0
  stx help_reload
  stx PPUADDR
  stx PPUDATA
  inx
  lda #$00
:
  sta PPUDATA
  inx
  bne :-

  ldx #4
  jsr ppu_clear_oam
  stx OAM+0
  stx OAM+3
  dex
  stx OAM+1
  lda #$20
  sta OAM+2
  rts
.endproc

.proc hill_zone_do_raster
  ; Wait for sprite 0 hit to turn OFF (top of screen)
  :
    bit PPUSTATUS
    bvs :-
  lda #0
  sta hill_zone_lastfinex

  ; Wait for sprite 0 hit to turn back ON
  lda #%11000000
  :
    bit PPUSTATUS
    beq :-

  lda tvSystem
  lsr a  ; C set: PAL NES; C clear: NTSC or Dendy
  ldy #0
  bcc :+
    ldy #splittable_pal-splittable_ntsc
  :
splitloop:
  ldx splittable_ntsc,y
  iny
  lda splittable_ntsc,y
  beq splitdone
  iny
  sta 0
  :
    inx
    bne :-
    inc 0
    bne :-
  lda hill_zone_xlo
  sta 0
  lda hill_zone_xhi
  ldx splittable_ntsc,y
  beq norot
  rotloop:
    lsr a
    ror 0
    dex
    bne rotloop
  norot:
  ldx 0
  jsr onesplit
  iny
  bne splitloop
splitdone:
  rts

onesplit:
  and #$01
  ora #VBLANK_NMI|BG_0000|OBJ_1000
  sta PPUCTRL
  txa
  and #$F8
  ora hill_zone_lastfinex
  ; Set the current fine scroll with the next coarse scroll, because
  ; fine scroll takes effect immediately whereas coarse scroll waits
  ; for x=256
  sta PPUSCROLL
  sta PPUSCROLL
  ; Now waste a bit of time waiting for vblank
  txa
  and #$07
  sta hill_zone_lastfinex
  jsr waste12
  jsr waste12
  stx PPUSCROLL
  stx PPUSCROLL
waste12:
  rts
.endproc

.segment "RODATA"

splittable_ntsc:
  .word -128 & $FFFF
  .byte 3
  .word -872 & $FFFF
  .byte 2
  .word -3234 & $FFFF
  .byte 0
  .word 0
splittable_pal:
  .word -115 & $FFFF
  .byte 3
  .word -818 & $FFFF
  .byte 2
  .word -3030 & $FFFF
  .byte 0
  .word 0


.segment "BANK00"

