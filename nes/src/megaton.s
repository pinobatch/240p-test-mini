;
; Manual lag test for 240p test suite
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
.importzp helpsect_timing_and_reflex_test
.importzp RF_megaton, RF_megaton_end

; Megaton is the manual lag test.

CENTERPOS = 128
LEFTWALL = 128-36
RIGHTWALL = 128+36
MAX_TESTS = 10
; Normally sides are 72 apart. When randomize is on, the side is
; temporarily moved (rand()&0x0F)-8 pixels to the right of its
; normal position.
num_tests = test_state + MAX_TESTS
bgcolor = test_state + 15
mt_dirty  = test_state + 16
mt_cursor_y = test_state + 17
reticlepos = test_state + 18
reticletarget = test_state + 19
reticledir = test_state + 20  ; 1: horizontal; 2: vertical; 3: both
lastgrade = test_state + 21  ; $80: A not yet pressed this pass
lastrawlag = test_state + 22  ; in signed magnitude (7 set: early)
enableflags = test_state + 23

EN_RANDOM = $80
EN_BEEP = $40

MT_DIRTY_CBOXCOLOR = $01
MT_DIRTY_RAWLAG = $02
MT_DIRTY_LAG_HISTORY = $04


; 00-17: Reticle tiles
; 18-44: Static labels
; 45-7F: Grade labels
; 80-87: Last raw lag
; 88-9B: Raw lag values
RAWLAG_TILE_BASE = $80
LAG_HISTORY_TILE_BASE = $88
TILES_PER_LAG_HISTORY = $02

.rodata

exact_msg:  .byte "exact",0
late_msg:   .byte "late",0
early_msg:  .byte "early",0
msg_frames: .byte " frames", 0

; The timing window widths on DDR Extreme are 2, 4, 11, 17, 27
; half frames, and the colors are $20,$38,$2A,$21,$24,$16,$0F.
; We used to display a DDR style grade, but it proved too tempting to
; anticipate the press if you're used to playing DDR on a laggy TV.

reticle_y:     .byte <-33,<-33,<-33,<-33,<-25,<-25,<-17,<-17, <-9, <-9, <-9, <-9
reticle_tile:  .byte  $04, $05, $06, $07, $08, $0B, $0C, $0F, $10, $11, $12, $13
reticle_x:     .byte <-16, <-8,   0,   8,<-16,   8,<-16,   8,<-16, <-8,   0,   8

.segment "CODE02"

.proc do_manual_lag
  lda #1
  sta reticledir
  lsr a
  sta num_tests
  sta mt_cursor_y
  lda #EN_RANDOM|EN_BEEP  ; SNES 1.03 made beeping the default
  sta enableflags

.if 0
  ldy #MAX_TESTS-1
:
  tya
  asl a
  asl a
  sta test_state,y
  dey
  bpl :-
  jmp megaton_show_results
.endif

restart:
  lda #MT_DIRTY_CBOXCOLOR
  sta mt_dirty
  lda nmis
  tax
  eor #$55
  jsr _srand

  lda #VBLANK_NMI
  sta lastgrade
  sta help_reload
  sta vram_copydsthi
  sta PPUCTRL
  asl a
  sta PPUMASK

  tax
  tay
  lda #8
  jsr unpb53_file

  jsr rf_load_yrgb_palette
  lda #$3F
  sta PPUADDR
  lda #$13
  sta PPUADDR
  lda #$20
  sta PPUDATA
  lda #RF_megaton
  jsr rf_load_layout
  lda #LEFTWALL
  sta reticlepos
  lda #RIGHTWALL
  sta reticletarget

  ; Clear current lag and lag history tiles
  ldx #$08
  lda #$00
  tay
  jsr ppu_clear_nt
  jsr draw_lag_history_so_far

  ; Set up audio output
  lda #$0F
  sta SNDCHN
  lda #8
  sta $4001  ; disable sweep
  sta $4005
  lda #$B0
  sta $4000  ; volume=0
  sta $4004
  lda #223
  sta $4006  ; channel 2 (A button): 500 Hz
  lsr a
  sta $4002  ; channel 1 (reticle): 1000 Hz
  lda #$00
  sta $4003
  sta $4007

  ; Now everything is set up

loop:
  ldx #0
  stx oam_used

  jsr move_reticle

  ; Draw reticle
  lda reticledir
  lsr a
  bcc :+
    ldx reticlepos
    ldy #128
    jsr draw_one_reticle
  :
  lda reticledir
  and #2
  beq :+
    ldx #128
    ldy reticlepos
    jsr draw_one_reticle
  :
  jsr mt_draw_cursor
  ldx oam_used
  jsr ppu_clear_oam

  ; Prepare background updates if there's not already one prepared
  lda vram_copydsthi
  bpl prepdone
  lda mt_dirty
  lsr a
  lsr a
  bcc nopreprawlag
    jsr mt_prepare_rawlag
    jmp prepdone
  nopreprawlag:
  lsr a
  bcc prepdone
    lda num_tests
    jsr mt_prepare_lag_history
  prepdone:

  ; Black unless reticles aligned and audio on
  lda #$0F
  bit enableflags
  bvc nobeep_nowhite
  ldx reticlepos
  cpx #128
  bne nobeep_nowhite
  lda #$20
nobeep_nowhite:
  sta bgcolor

  jsr ppu_wait_vblank

  ; Update the first thing that's dirty  
  lda mt_dirty
  lsr a
  bcc nocboxupdate
    jsr update_checkboxes
    jmp vramupdatedone
  nocboxupdate:
  lda vram_copydsthi
  bmi vramupdatedone
    jsr rf_copy8tiles
    lda #$FF
    sta vram_copydsthi
  vramupdatedone:

  ; Flash if audio enabled
  ldy #$3F
  ldx #$00
  sty PPUADDR
  stx PPUADDR
  ldy bgcolor
  sty PPUDATA

  lda #VBLANK_NMI|OBJ_0000|BG_0000
  jsr ppu_oam_dma_screen_on_xy0

  jsr read_pads
  ; If Start is pressed, pause and show help screen
  lda new_keys+0
  and #KEY_START
  beq not_help
    ldx #$B0  ; turn off beeper during help
    stx $4000
    ldx #helpsect_timing_and_reflex_test
    lda #KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT
    jsr helpscreen
    jmp do_manual_lag::restart
  not_help:

  lda #$B0
  ldy bgcolor
  cpy #$0F
  beq no_reticle_beep
  lda #$BC
no_reticle_beep:
  sta $4000

  lda #$B0
  bit enableflags
  bvc no_beep_this_frame
  ldx new_keys
  bpl no_beep_this_frame
  lda #$BC
no_beep_this_frame:
  sta $4004

  ; If A is pressed for the first time this pass, grade it
  lda new_keys+0
  and lastgrade
  bpl notA
    jsr grade_press  
  notA:

  lda new_keys+0
  jsr handle_cursor_move

  ldy num_tests
  cpy #MAX_TESTS
  bcs megaton_show_results
  lda new_keys+0
  and #KEY_B
  bne done
    jmp loop
  done:
  ; fall through
.endproc
.proc silence_pulses
  lda #$B0  ; silence beeper
  sta $4000
  sta $4004
  rts
.endproc

.proc megaton_show_results
  jsr silence_pulses
  lda #VBLANK_NMI
  sta PPUCTRL
  sta help_reload
  asl a
  sta PPUMASK
  lda #RF_megaton_end
  jsr rf_load_layout
  jsr draw_lag_history_so_far

  ; Sum
lagtotal = $0C
lagtotal100 = $0D
  lda #0
  sta lagtotal100
  ldy #MAX_TESTS-1
  clc
  lagsumloop:
    adc test_state,y
    bcc addwrap1
      sbc #200
      inc lagtotal100
      inc lagtotal100
    addwrap1:
    cmp #100
    bcc addwrap0
      sbc #100
      inc lagtotal100
      bcs addwrap1
    addwrap0:
    dey
    bpl lagsumloop
  sta lagtotal

  ; Write sum
  ldy #0
  lda lagtotal100
  beq lessthan100frames
    jsr bcd8bit
    tax
    lda bcd_highdigits
    beq :+
      ora #'0'
      sta help_line_buffer,y
      iny
    :
    txa
    ora #'0'
    sta help_line_buffer,y
    iny
  lessthan100frames:
  lda lagtotal
  jsr bcd8bit
  ora #'0'
  sta help_line_buffer+2,y
  lda bcd_highdigits
  eor #'0'
  sta help_line_buffer,y
  lda #'.'
  sta help_line_buffer+1,y
  iny
  iny
  iny
  ldx #0
  suffixloop:
    lda msg_frames,x
    sta help_line_buffer,y
    beq suffixdone
    inx
    iny
    bpl suffixloop
  suffixdone:

  jsr clearLineImg
  ldy #<help_line_buffer
  lda #>help_line_buffer
  ldx #8
  jsr vwfPuts
  lda #%0011
  jsr rf_color_lineImgBuf
  lda #>(RAWLAG_TILE_BASE * 16)
  sta vram_copydsthi
  lda #<(RAWLAG_TILE_BASE * 16)
  sta vram_copydstlo
  jsr rf_copy8tiles
  
  ; Set the background color
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda #$0F
  sta PPUDATA

loop:
  jsr ppu_wait_vblank
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0
  jsr read_pads
  lda new_keys+0
  and #KEY_B|KEY_START
  beq loop
  rts
.endproc

; movement ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc move_reticle
  ; Move reticle
  lda reticletarget
  cmp reticlepos
  lda #0
  adc #$FF
  sec
  rol a
  clc
  adc reticlepos
  sta reticlepos
  cmp reticletarget
  bne not_turn_around
    lda #$FF
    sta lastgrade
    lda #MT_DIRTY_CBOXCOLOR
    ora mt_dirty
    sta mt_dirty
    lda #RIGHTWALL
    bit reticlepos
    bpl :+
      lda #LEFTWALL
    :
    sta reticletarget
    bit enableflags
    bpl :+
      jsr _rand
      and #$0F
      clc
      adc #<-8
      clc
      adc reticletarget
      sta reticletarget
    :
  not_turn_around:

  rts
.endproc

.proc handle_cursor_move
  lsr a
  bcc not_increase
    ldy mt_cursor_y
    bne enable_toggles
    inc reticledir
    lda reticledir
    cmp #4
    bcc :+
      lda #1
      sta reticledir
    :
  request_checkbox_update:
    lda #MT_DIRTY_CBOXCOLOR
    ora mt_dirty
    sta mt_dirty
    rts
  not_increase:

  lsr a
  bcc not_decrease
    ldy mt_cursor_y
    bne enable_toggles
    dec reticledir
    bne :+
      lda #3
      sta reticledir
    :
    jmp request_checkbox_update
  enable_toggles:
    dey
    bne :+
      lda #EN_RANDOM
      bmi have_toggle_id
    :
    lda #EN_BEEP
    have_toggle_id:
    eor enableflags
    sta enableflags
    jmp request_checkbox_update
  not_decrease:

  lsr a
  bcc not_next_row
    lda mt_cursor_y
    cmp #2
    bcs :+
      inc mt_cursor_y
    :
    jmp request_checkbox_update
  not_next_row:

  lsr a
  bcc done
    lda mt_cursor_y
    beq :+
      dec mt_cursor_y
    :
    jmp request_checkbox_update
  done:
  rts
.endproc

;;
; Grades an A button press.
.proc grade_press
absdist = $0C

  lda reticlepos
  eor #$80
  bpl notNeg
    eor #$FF
    sec
    adc #1
  notNeg:
  sta absdist
  
  ldy #0
  sty lastgrade

  ; If absdist is nonzero, bit 7 of reticlepos XOR reticletarget
  ; is true only if early.
  lda absdist
  beq :+
    lda reticlepos
    eor reticletarget
    and #$80
    ora absdist
  :
  sta lastrawlag

  ; Record only on-time and late presses
  bmi skip_recording_early
    ldy num_tests
    sta test_state,y
    inc num_tests
    lda #MT_DIRTY_LAG_HISTORY
    ora mt_dirty
    sta mt_dirty
  skip_recording_early:
  
  lda #MT_DIRTY_CBOXCOLOR|MT_DIRTY_RAWLAG
  ora mt_dirty
  sta mt_dirty
  rts
.endproc

; Background updates ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MT_CHECKBOX_TILE = $02

;;
; Updates the checkboxes
.proc update_checkboxes
reticledirbits = $00
enfbits = $01
  lda mt_dirty
  and #<~MT_DIRTY_CBOXCOLOR
  sta mt_dirty
  lda reticledir
  sta reticledirbits
  lda enableflags
  sta enfbits

  ; $230D: horizontal display enabled
  ; $232D: randomize enabled
  ; $233D: audio enabled
  ; $2315: vertical display enabled
  ldy #VBLANK_NMI|VRAM_DOWN
  sty PPUCTRL
  ldy #$23
  sty PPUADDR
  lda #$0D
  sta PPUADDR
  lsr reticledirbits
  lda #MT_CHECKBOX_TILE>>1
  rol a
  sta PPUDATA
  asl enfbits
  lda #MT_CHECKBOX_TILE>>1
  rol a
  sta PPUDATA
  asl enfbits
  lda #MT_CHECKBOX_TILE>>1
  rol a
  sta PPUDATA

  sty PPUADDR
  lda #$15
  sta PPUADDR
  lsr reticledirbits
  lda #MT_CHECKBOX_TILE>>1
  rol a
  sta PPUDATA
  rts
.endproc

.proc mt_prepare_rawlag
  jsr clearLineImg
  lda lastrawlag
  beq is_exact
  and #$7F
  jsr bcd8bit
  ora #'0'
  ldx #16
  jsr vwfPutTile
  lda bcd_highdigits
  beq less_than_ten
    ora #'0'
    ldx #11
    jsr vwfPutTile
  less_than_ten:  
  ldy #<late_msg
  lda #>late_msg
  ldx #26
  bit lastrawlag
  bpl have_text
  ldy #<early_msg
  lda #>early_msg
  bne have_text
is_exact:  
  ldy #<exact_msg
  lda #>exact_msg
  ldx #20
have_text:
  jsr vwfPuts
  lda #<~MT_DIRTY_RAWLAG
  and mt_dirty
  sta mt_dirty
  lda #<(RAWLAG_TILE_BASE << 4)
  sta vram_copydstlo
  lda #>(RAWLAG_TILE_BASE << 4)
  sta vram_copydsthi
  lda #%0011
  jmp rf_color_lineImgBuf
.endproc

.proc mt_prepare_lag_history
entry_to_draw = $0C
x_position = $0D

  sec
  sbc #8/TILES_PER_LAG_HISTORY
  bcs :+
    lda #0
  :
  sta entry_to_draw

  ; Calculate destination address in VRAM
  clc
  adc #LAG_HISTORY_TILE_BASE/TILES_PER_LAG_HISTORY
  sta vram_copydsthi
  lda #0
  .repeat 3
    lsr vram_copydsthi
    ror a
  .endrepeat
  sta vram_copydstlo

  jsr clearLineImg
  lda #<~MT_DIRTY_LAG_HISTORY
  and mt_dirty
  sta mt_dirty

  ; Actually draw each entry
  lda #0
  entryloop:
    sta x_position
    ldy entry_to_draw
    cpy num_tests
    bcs no_more_entries
    inc entry_to_draw
    lda test_state,y
    jsr bcd8bit
    ora #'0'
    tay
    lda #5
    ora x_position
    tax
    tya
    jsr vwfPutTile
    lda bcd_highdigits
    beq less_than_ten
      ora #'0'
      ldx x_position
      jsr vwfPutTile
    less_than_ten:
    lda x_position
    clc
    adc #8 * TILES_PER_LAG_HISTORY
    bpl entryloop
  no_more_entries:

  lda #%0011
  jmp rf_color_lineImgBuf
  rts
.endproc

.proc draw_lag_history_so_far
tests_drawn = $0E

  lda #8/TILES_PER_LAG_HISTORY
  drawlagsloop:
    sta tests_drawn
    jsr mt_prepare_lag_history
    jsr rf_copy8tiles
    lda tests_drawn
    cmp #MAX_TESTS
    bcs drawlagsdone
    adc #8/TILES_PER_LAG_HISTORY
    cmp #MAX_TESTS
    bcc drawlagsloop
    lda #MAX_TESTS
    bcs drawlagsloop
  drawlagsdone:
  rts
.endproc

; Sprite drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc draw_one_reticle
basex = 0
basey = 1
  stx basex
  sty basey
  ldx oam_used
  ldy #11
objloop:
  lda reticle_y,y
  clc
  adc basey
  sta OAM,x
  inx
  lda reticle_tile,y
  sta OAM,x
  inx
  lda #0
  sta OAM,x
  inx
  lda reticle_x,y
  clc
  adc basex
  sta OAM,x
  inx
  dey
  bpl objloop
  stx oam_used
  rts
.endproc

MEGATON_CURSOR_TILE = $01

.proc mt_draw_cursor
  lda mt_cursor_y
  asl a
  asl a
  asl a
  adc #191
  ldx oam_used
  sta OAM,x
  inx
  lda #MEGATON_CURSOR_TILE
  sta OAM,x
  inx
  lda #0
  sta OAM,x
  inx
  lda #32
  sta OAM,x
  inx
  stx oam_used
  rts
.endproc
