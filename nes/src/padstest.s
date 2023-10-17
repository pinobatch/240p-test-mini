; NES controller test
; Copyright 2023 Damian Yerrick
; license: GNU GPL version 2 or later

.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_input_test_menu, helpsect_input_test
.importzp helpsect_under_construction
.importzp RF_serial_analyzer, RF_input_fcpads, RF_input_fourscore
.importzp RF_input_power_pad, RF_input_snes_pad, RF_input_vaus
.importzp RF_input_mouse

; Remaining activities within padstest (issue #42)
; - [ ] Super NES Mouse

exit_time = test_state + 0
buttonset = test_state + 1

mouse_dirty_peak = test_state + 0
mouse_x = test_state + 4
mouse_y = test_state + 5
mouse_dx = test_state + 6
mouse_dy = test_state + 7 
mouse_peak_vel = test_state + 8
mouse_accel_tile = test_state + 13

vaus_value_lo = test_state + 2
vaus_value_hi = test_state + 3
rangeleft_lo = test_state + 4
rangeleft_hi = test_state + 5
rangeright_lo = test_state + 6
rangeright_hi = test_state + 7

cur_semitone = test_state + 14



.code
.align 32
; Serial analyzer ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NUM_READS = 32
NUM_PORTS = 2
BITS_PER_PORT = 5
LA_NUM_CHANNELS = NUM_PORTS * BITS_PER_PORT

serial_read_data0 = $0100
serial_read_data1 = serial_read_data0 + NUM_READS
serial_disp_data = OAM
SIZEOF_SERIAL_DISP_DATA = NUM_READS / 2 * LA_NUM_CHANNELS
SERIAL_BLANK_TILE = $00
SERIAL_BASE_TILE = $0C
SERIAL_EXIT_HOLD_TIME = 30

.proc serial_read
  ldx #1
  stx $4016
  dex
  stx $4016
  readloop:
    ; Burn a few cycles because the Hyper Click mouse is slow
    ; to set up its 17th bit
    pha
    pla
    lda $4016
    sta serial_read_data0,x
    lda $4017
    sta serial_read_data1,x
    inx
    cpx #NUM_READS
    bcc readloop
  .assert >* = >readloop, error, "serial read loop crosses back boundary invalidating rate in help text"
  rts
.endproc

; fast transfer serial traces
.proc serial_present
  ; reformat serial_read_data to serial_disp_data
  ; Each 2 bytes of serial_read_data correspond to 5 bytes of
  ; serial_disp_data.

  ldx #SIZEOF_SERIAL_DISP_DATA/2-1
  lda #SERIAL_BASE_TILE/4
  clear_disp_loop:
    sta serial_disp_data,x
    sta serial_disp_data+SIZEOF_SERIAL_DISP_DATA/2,x
    dex
    bpl clear_disp_loop
  inx

  format_disp_loop:
    ; put 1 bit from each line of each controller into each output cell
    lda serial_read_data0,y
    jsr shift1byte
    lda serial_read_data1,y
    jsr shift1byte

    ; put a second bit from each controller into the same output cell
    txa
    sec
    sbc #LA_NUM_CHANNELS
    tax
    iny
    lda serial_read_data0,y
    jsr shift1byte
    lda serial_read_data1,y
    jsr shift1byte
    iny
    cpy #NUM_READS
    bcc format_disp_loop

  ldy #SERIAL_BLANK_TILE
  ldx #LA_NUM_CHANNELS-1
  bit PPUSTATUS
  jsr input_vsync
  xferloop:
    ; seek (16)
    lda serial_dst_hi,x
    sta PPUADDR
    lda serial_dst_lo,x
    sta PPUADDR

    ; send (140)
    .repeat ::NUM_READS/8, I
      .if I>0
        sty PPUDATA
      .endif
      .repeat 4, J
        lda serial_disp_data+LA_NUM_CHANNELS*(4*I+J),x
        sta PPUDATA
      .endrepeat
    .endrepeat

    ; loop (5)
    dex
    bpl xferloop
  sty PPUSCROLL
  sty PPUSCROLL
  lda #VBLANK_NMI|BG_0000
  sta PPUCTRL
  lda #BG_ON
  sta PPUMASK
  rts

shift1byte:
  and #(1 << BITS_PER_PORT) - 1
  ora #1 << BITS_PER_PORT
  lsr a
  shift1loop:
    rol serial_disp_data,x
    inx
    lsr a
    bne shift1loop
  rts
.endproc

.proc do_serial_analyzer
  lda #VBLANK_NMI
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK
  tax
  tay
  lda #12
  sta exit_time
  jsr unpb53_file
  jsr rf_load_yrgb_palette
  lda #RF_serial_analyzer
  jsr rf_load_layout

  loop:
    jsr serial_read
    jsr serial_present
    lda serial_read_data0+2  ; SELECT
    and serial_read_data0+3  ; START
    lsr a  ; CF set if select and start are held
    bcs :+
      lda #SERIAL_EXIT_HOLD_TIME
      sta exit_time
    :
    dec exit_time
    bne loop    
  jmp do_input_test
.endproc

.rodata
SERIAL_LEFT = 10
SERIAL_TOP = 10
SERIAL_ROWS_BETWEEN_PORTS = 1
.define SERIAL_ROW_ADDR(port, bitnum) $2000 + SERIAL_LEFT + 32 * (SERIAL_TOP + port * (BITS_PER_PORT + SERIAL_ROWS_BETWEEN_PORTS) + bitnum)
serial_dst_hi:
.repeat NUM_PORTS, P
  .repeat BITS_PER_PORT, B
    .byte >(SERIAL_ROW_ADDR P, B)
  .endrepeat
.endrepeat
serial_dst_lo:
.repeat NUM_PORTS, P
  .repeat BITS_PER_PORT, B
    .byte <(SERIAL_ROW_ADDR P, B)
  .endrepeat
.endrepeat

; Famicom and NES controllers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.code
.proc load_std_controller_images
  lda #13
.endproc
.proc load_controller_images_A
  ldx #VBLANK_NMI
  stx help_reload
  stx PPUCTRL
  stx cur_semitone
  ldy #0
  sty PPUMASK
  ldx #$08
  stx exit_time
  ora #0
  bmi :+
    jsr unpb53_file
  :

  ldx #$00
  stx PPUADDR
  stx PPUADDR
  chrloop:
    lda controller_test_obj_chr,x
    sta PPUDATA
    inx
    cpx #controller_test_obj_chr_end-controller_test_obj_chr
    bne chrloop

  jsr input_vsync
  ldx #0
  lda #$3F
  sta PPUADDR
  stx PPUADDR
  jsr wr_palette
  wr_palette:
    ldx #0
    palloop:
      lda controller_test_palette,x
      sta PPUDATA
      inx
      cpx #controller_test_palette_end-controller_test_palette
      bcc palloop
    rts
.endproc

PRESSED_BUTTON_CIRCLE_TILE = 1

;;
; @param X offset from button_sets_base
.proc nes_buttons_draw_obj
setdef_offset = $00

found_same_button = $0E
found_other_button = $0F

SIZEOF_BUTTON_PARAMS = 6
read_data_offset = $06
mask = $05
yoffset = $04
xypos_offset = $03
scale_degree = $02
count = $01

  ldy #$FF
  sty found_same_button
  sty found_other_button

next_group:
  ldy #SIZEOF_BUTTON_PARAMS
  :
    lda button_sets_base,x
    sta $0000,y
    inx
    dey
    bne :-

  stx setdef_offset
  ldx oam_used
  buttonloop:
    ; Is the button pressed?
    ldy read_data_offset
    lda serial_read_data0,y
    and mask
    beq next_obj
      ldy xypos_offset
      lda button_ypos_base,y
      clc
      adc yoffset
      sta OAM,x
      inx
      lda #PRESSED_BUTTON_CIRCLE_TILE
      sta OAM,x
      inx
      lda #0
      sta OAM,x
      inx
      lda button_xpos_base,y
      sta OAM,x
      ; send to speaker too
      ldy scale_degree
      bmi find_semitone_done
      lda SCALES,y
      cmp cur_semitone
      beq find_semitone_same
        sta found_other_button
        bne find_semitone_done
      find_semitone_same:
        sta found_same_button
      find_semitone_done:
      inx
    next_obj:
    inc read_data_offset
    inc xypos_offset
    inc scale_degree
    dec count
    bne buttonloop
  stx oam_used
  ldx setdef_offset
  lda button_sets_base,x
  bpl next_group

  ; same button takes priority over different button
  ldy found_same_button
  bpl pads_play_semitone_y
  ldy found_other_button
.endproc
.proc pads_play_semitone_y
  ; If no buttons were found, silence the tone
  tya
  bpl not_silent
    ; Neither same nor other button was found. End note
    sty cur_semitone
    lda #$B0
    sta $4000
  play_semitone_done:
    rts
  not_silent:
    lda #$BC
    sta $4000  ; Set volume to 12
    lda #$08
    sta $4001  ; Disable sweep
    cpy cur_semitone
    beq play_semitone_done  ; Change pitch only if changed
    lda periodTableLo,y
    sta $4002
    lda periodTableHi,y
    sta $4003
    sty cur_semitone
    rts
.endproc

.proc do_fourscore_test
  jsr load_std_controller_images
  ldx #fourscore_button_sets-button_sets_base
  lda #RF_input_fourscore
  bne do_pads_kernel
.endproc

.proc do_power_pad_test
  lda #14
  jsr load_controller_images_A
  ldx #power_pad_button_sets-button_sets_base
  lda #RF_input_power_pad
  bne do_pads_kernel
.endproc

.proc do_snes_pad_test
  jsr load_std_controller_images
  ldx #snes_pad_button_sets-button_sets_base
  lda #RF_input_snes_pad
  bne do_pads_kernel
.endproc

.proc do_fcpads_test
  jsr load_std_controller_images
  ldx #fcpads_button_sets-button_sets_base
  lda #RF_input_fcpads
.endproc
.proc do_pads_kernel
  stx buttonset
  jsr rf_load_layout
  loop:
    jsr serial_read
    ldx #0
    stx oam_used
    ldx buttonset
    jsr nes_buttons_draw_obj
    ldx oam_used
    jsr ppu_clear_oam
    jsr input_vsync
    jsr input_screen_on
    lda buttonset
    cmp #first_non_selectstart_button_set - button_sets_base
    bcc is_select_start_exit
    lda serial_read_data0+1  ; B
    lsr a
    bcc loop
  jmp do_input_test

  is_select_start_exit:
    lda serial_read_data0+2  ; SELECT
    and serial_read_data0+3  ; START
    lsr a  ; CF set if select and start are held
    bcs :+
      lda #SERIAL_EXIT_HOLD_TIME
      sta exit_time
    :
    dec exit_time
    bne loop    
  jmp do_input_test
.endproc

.proc input_vsync
  lda nmis
  :
    cmp nmis
    beq :-
  rts
.endproc

.proc input_screen_on
  ldx #0
  stx OAMADDR
  lda #>OAM
  sta OAM_DMA
  ldy #0
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  sec
  jmp ppu_screen_on
.endproc

.rodata
controller_test_palette:
  .byte $0F,$20,$28,$16  ; Text and FC
  .byte $0F,$00,$10,$16  ; NES
  .byte $0F,$00,$10,$13  ; Super NES
  .byte $0F,$12,$16,$10  ; power pad
controller_test_palette_end:

controller_test_obj_chr:
  .incbin "obj/nes/pads_buttons16.chr"
controller_test_obj_chr_end:

; serial_read_data0 offset, mask, Y offset, xypos offset, scale, count
button_sets_base:
fcpads_button_sets:
  .byte  0, $01,   0, nes_button_xpos-BTNBASE, major_scale-SCALES, 8
  .byte 32, $01,  40, nes_button_xpos-BTNBASE, major_scale-SCALES, 8
  .byte  0, $02,  80, nes_button_xpos-BTNBASE, major_scale-SCALES, 8
  .byte 32, $02, 120, nes_button_xpos-BTNBASE, major_scale-SCALES, 8
  .byte  0, $04,   0, fc_mic_xpos-BTNBASE,     fc_mic_scale-SCALES, 1
  .byte $FF
fourscore_button_sets:
  .byte  0, $01,   0, nes_button_xpos-BTNBASE,    major_scale-SCALES, 8
  .byte  8, $01,  80, nes_button_xpos-BTNBASE,    major_scale-SCALES, 8
  .byte 16, $01, 112, fourscore_sig_xpos-BTNBASE, $80, 8
  .byte 32, $01,  40, nes_button_xpos-BTNBASE,    major_scale-SCALES, 8
  .byte 40, $01, 120, nes_button_xpos-BTNBASE,    major_scale-SCALES, 8
  .byte 48, $01, 120, fourscore_sig_xpos-BTNBASE, $80, 8
  .byte $FF
snes_pad_button_sets:
  .byte  0, $01,  40, snes_button_xpos-BTNBASE, chromatic_scale-SCALES, 12
  .byte 32, $01,  80, snes_button_xpos-BTNBASE, chromatic_scale-SCALES, 12
  .byte $FF
first_non_selectstart_button_set:
power_pad_button_sets:
  .byte 32, $08,   0, power_pad_xpos-BTNBASE,    chromatic_scale-SCALES, 8
  .byte 32, $10,   0, power_pad_d4_xpos-BTNBASE, chromatic_scale+8-SCALES, 4
  .byte $FF

BTNBASE:
button_xpos_base:
nes_button_xpos:
  .byte 147, 138, 118, 126, 104, 104,  99, 109
fourscore_sig_xpos:
  .byte  96, 104, 112, 120, 128, 136, 144, 152
snes_button_xpos:
  .byte 143, 137, 120, 126, 106, 106, 102, 110, 149, 143, 107, 142
power_pad_xpos:
  .byte 116, 100, 100, 100, 116, 116, 132, 132
power_pad_d4_xpos:
  .byte 148, 132, 148, 148
fc_mic_xpos:
  .byte 126
button_ypos_base:
  .byte  58,  58,  58,  58,  49,  59,  54,  54  ; NES
  .byte  87,  87,  87,  87,  87,  87,  87,  87  ; Four Score sig
  .byte  57,  51,  54,  54,  47,  55,  51,  51, 52,  46,  35,  35  ; SNES
  .byte  99, 99, 115, 131, 115, 131, 131, 115, 99, 99, 131, 115  ; Power Pad
  .byte  92  ; FC mic

SCALES:
major_scale:
  .byte 27, 29, 31, 32, 34, 36, 38, 39
chromatic_scale:
  .repeat 12, I
    .byte 27+I
  .endrepeat
fc_mic_scale:
  .byte 50

; Mouse test ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MOUSE_ACCEL_TL = $2000 + 17 + 16*32

.proc do_mouse_test
  lda #160
  sta mouse_x
  lsr a
  sta mouse_y
  lda #0
  sta mouse_peak_vel
  jsr mouse_poll
  lda #$FF
  jsr load_controller_images_A
  lda #RF_input_mouse
  jsr rf_load_layout
  ldx #0
  :
    lda mouse_oam_data,x
    sta OAM,x
    inx
    cpx #mouse_oam_data_end-mouse_oam_data
    bcc :-
  jsr ppu_clear_oam

  loop:
    jsr mouse_poll
    lda serial_read_data0+1  ; B Button
    lsr a
    bcs done
    lda cur_keys
    eor #$FF
    and serial_read_data0+2  ; Select Button
    and #$01
    beq no_pulse
      sta $4016
      nop
      bit $4017
      lsr a
      sta $4016
    no_pulse:
    lda serial_read_data0+2  ; Select Button
    sta cur_keys
    jsr mouse_draw
    lda #%0001
    jsr rf_color_lineImgBuf  ; finish drawing text
    jsr input_vsync
    jsr rf_copy8tiles
    lda #>MOUSE_ACCEL_TL
    sta PPUADDR
    lda #<MOUSE_ACCEL_TL
    sta PPUADDR
    ldy #4
    ldx mouse_accel_tile
    : 
      stx PPUDATA
      inx
      dey
      bne :-
    jsr input_screen_on
    jmp loop
  done:
  jmp do_input_test
.endproc

.proc mouse_poll
  jsr serial_read
  ldy #16
  ldx #1
  jsr get_one_coord
  dex
get_one_coord:
  lda #1
  sta $00
  bitloop:
    lda serial_read_data1,y
    lsr a
    iny
    rol $00
    bcc bitloop
  lda $00
  sta mouse_dx,x
  and #$7F
  cmp mouse_peak_vel
  bcc :+
  beq :+
    sta mouse_peak_vel
    inc mouse_dirty_peak
  :
  lda $00
  bmi is_negative
    clc
    adc mouse_x,x
    bcs xclamp
    cmp mouse_xy_max,x
    bcc have_x
    xclamp:
      lda mouse_xy_max,x
    have_x:
    sta mouse_x,x
    rts
  is_negative:
    eor #$7F  ; 128-255 to 255-128
    sec       ; 255-128 to 256-129 
    adc mouse_x,x
    bcs have_x
    lda #0
    bcc have_x
.endproc

MOUSE_PEAK_CHR_DST = $0100
MOUSE_POS_CHR_DST = $0080
MOUSE_B_X = 144
MOUSE_B_Y = 120
MOUSE_SPEED_NAMES_BASE_TILE = $18

MOUSE_LMB = serial_read_data1+9
MOUSE_RMB = serial_read_data1+8

.proc mouse_draw
  lda mouse_x
  sta OAM+7
  sta OAM+3
  lda mouse_y
  tay
  clc
  adc #7
  sta OAM+4
  dey
  sty OAM+0
  lda MOUSE_LMB
  and #$01
  eor #$01
  sta OAM+10
  lda MOUSE_RMB
  and #$01
  eor #$01
  sta OAM+14
  lda serial_read_data1+11  ; accel low
  lsr a
  lda serial_read_data1+10  ; accel high
  and #$01
  rol a
  asl a
  asl a
  adc #MOUSE_SPEED_NAMES_BASE_TILE
  sta mouse_accel_tile
  
  ldy #27
  lda MOUSE_LMB
  lsr a
  bcs have_semitone
  ldy #29
  lda MOUSE_RMB
  lsr a
  bcs have_semitone
    ldy #$FF
  have_semitone:
  jsr pads_play_semitone_y

  jsr clearLineImg
  lda mouse_dirty_peak
  beq not_dirty_peak
    lda #<MOUSE_PEAK_CHR_DST
    sta vram_copydstlo
    .if ::MOUSE_PEAK_CHR_DST <> 0
      lda #0
    .endif
    sta mouse_dirty_peak
    lda #>MOUSE_PEAK_CHR_DST
    sta vram_copydsthi
    ldy mouse_peak_vel
    ldx #0
    jmp mouse_3digits
  not_dirty_peak:
    lda #<MOUSE_POS_CHR_DST
    sta vram_copydstlo
    lda #>MOUSE_POS_CHR_DST
    sta vram_copydsthi
    ldx #0
    ldy mouse_x
    jsr mouse_3digits
    ldx #15
    lda #','
    jsr vwfPutTile
    ldx #17
    ldy mouse_y
    jsr mouse_3digits
    ldx #32
    lda mouse_dx
    jsr mouse_low7bits
    ldx #32
    lda mouse_dx
    jsr put_sign
    ldx #47
    lda #','
    jsr vwfPutTile
    ldx #49
    lda mouse_dy
    jsr mouse_low7bits
    ldx #49
    lda mouse_dy
    ; fall through to put_sign

put_sign:
  asl a
  beq no_dy_sign
    lda #'+'
    bcc :+
      lda #'-'
    :
    jsr vwfPutTile
  no_dy_sign:
  rts
.endproc

.rodata
mouse_oam_data:
  .byte $FF,           $02, $00, $FF  ; OAM+0: top half of arrow
  .byte $FF,           $03, $00, $FF  ; OAM+4: bottom half of arrow
  .byte MOUSE_B_Y - 1, $01, $00, MOUSE_B_X    ; OAM+8: LMB
  .byte MOUSE_B_Y - 1, $01, $00, MOUSE_B_X+8  ; OAM+12: RMB
mouse_oam_data_end:
mouse_xy_max:
  .byte 255, 239

; Arkanoid controller test ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.code
VAUS_Y = 96
VAUS_BUTTON_Y = 128
VAUS_GRID_TL = $2000 + (VAUS_Y / 8) * 32
VAUS_VALUE_TARGET = $0800
.proc do_vaus_test
  jsr input_vsync
  jsr vaus_poll
  ldx #VBLANK_NMI
  stx help_reload
  stx PPUCTRL
  stx vram_copydstlo
  stx rangeleft_hi
  ldx #$00
  stx vram_copydsthi
  stx rangeright_lo
  stx rangeright_hi
  ldy #$00
  sty PPUMASK
  lda #15
  jsr unpb53_file
  lda #RF_input_vaus
  jsr rf_load_layout
  lda #>VAUS_GRID_TL
  sta PPUADDR
  lda #<VAUS_GRID_TL
  sta PPUADDR
  jsr vaus_draw_grid_strip
  jsr vaus_draw_grid_strip
  ldx #0
  :
    lda vaus_oam_data,x
    sta OAM,x
    inx
    cpx #vaus_oam_data_end-vaus_oam_data
    bcc :-
  jsr ppu_clear_oam
  jsr input_vsync
  lda #$00
  jsr vaus_load_palette
  lda #$10
  jsr vaus_load_palette

  loop:
    jsr vaus_poll
    jsr vaus_draw
    jsr input_vsync
    jsr rf_copy8tiles
    lda #$3F
    sta PPUADDR
    lda #$15  ; palette 1: current position
    sta PPUADDR
    lda vaus_value_lo
    lsr a
    lda #$16
    ldx #$26
    bcs :+
      txa
    :
    sta PPUDATA
    stx PPUDATA
    eor #$30
    sta PPUDATA
    jsr input_screen_on
    lda cur_keys
    and #KEY_B
    beq loop
  done:
  jmp do_input_test
.endproc

.proc vaus_poll
  ; Arkanoid controller is weird.  It should be read *before*
  ; strobing, or only the 8 most significant bits will be correct.
  ; The least significant bit is readable only after the conversion
  ; has finished, which takes about 8 ms.
  lda #1 << (16 - 9)  ; Ring counter: when this 1 shifts out we're done
  sta vaus_value_lo
  ldx #0
  stx vaus_value_hi
  player2_loop:
    lda $4017
    tay
    inx
    and #$10
    eor #$10
    cmp #$01
    rol vaus_value_lo
    rol vaus_value_hi
    bcc player2_loop
  tya
  and #$08  ; get button state from last poll
  sta cur_keys+1

  ; Now we can strobe it to start the next conversion.
  lda #1
  sta $4016
  sta cur_keys+0
  lsr a
  sta $4016
  player1_loop:
    lda $4016
    lsr a
    rol cur_keys+0
    bcc player1_loop

  ldy vaus_value_lo
  ldx vaus_value_hi
  cpy rangeleft_lo
  txa
  sbc rangeleft_hi
  bcs not_decrease_left
    stx rangeleft_hi
    sty rangeleft_lo
  not_decrease_left:
  cpy rangeright_lo
  txa
  sbc rangeright_hi
  bcc not_increase_right
    stx rangeright_hi
    sty rangeright_lo
  not_increase_right:
  rts
.endproc

.proc vaus_draw
  ; Move fire button into place
  ldy #$FF
  lda cur_keys+1
  beq :+
    ldy #39
    lda #(VAUS_BUTTON_Y-1) ^ $FF
  :
  eor #$FF
  sta OAM+4
  jsr pads_play_semitone_y
  lda vaus_value_hi
  lsr a
  lda vaus_value_lo
  ror a
  sta OAM+3
  lda rangeleft_hi
  lsr a
  lda rangeleft_lo
  ror a
  sta OAM+11
  lda rangeright_hi
  lsr a
  lda rangeright_lo
  ror a
  sec
  sbc #5
  sta OAM+15

  jsr clearLineImg

  ldy vaus_value_lo
  lda vaus_value_hi
  ldx #0
  jsr vaus_3digits
  ldy rangeleft_lo
  lda rangeleft_hi
  ldx #16
  jsr vaus_3digits
  ldy rangeright_lo
  lda rangeright_hi
  ldx #36
  jsr vaus_3digits
  lda #'-'
  ldx #31
  jsr vwfPutTile

  lda #%0011
  jmp rf_color_lineImgBuf  ; finish drawing text
.endproc

.proc vaus_draw_grid_strip
  ldx #0
  loop:
    lda vaus_grid_strip_data,x
    and #$03
    sta PPUDATA
    eor vaus_grid_strip_data,x
    sta PPUDATA
    inx
    cpx #16
    bcc loop
  rts
.endproc

.proc vaus_load_palette
  ldx #$3F
  stx PPUADDR
  sta PPUADDR
  stx PPUDATA
  lda #$16
  sta PPUDATA
  lda #$20
  sta PPUDATA
  sta PPUDATA
  rts
.endproc


.proc mouse_low7bits
  and #$7F
  tay
.endproc

;;
; Writes 3-digit number Y (0 to 255) at position X
.proc mouse_3digits
  lda #0
.endproc
;;
; Writes 3-digit number AY (0 to 999) at position X
.proc vaus_3digits
xposition = $0F
  sty bcdNum+0
  sta bcdNum+1
  lda #0
  sta bcdNum+2
  stx xposition
  jsr bcdConvert24
  lda bcdResult+2
  beq no_hundreds
    ldx xposition
    ora #'0'
    jsr vwfPutTile
    jmp yes_tens
  no_hundreds:
  lda bcdResult+1
  beq no_tens
  yes_tens:
    lda #5
    clc
    adc xposition
    tax
    lda bcdResult+1
    ora #'0'
    jsr vwfPutTile
  no_tens:
  lda #10
  clc
  adc xposition
  tax
  lda bcdResult+0
  ora #'0'
  jmp vwfPutTile
.endproc

.rodata
vaus_grid_strip_data:
  .byte 3,1,2,1,2,1,2,1,3,1,2,1,2,1,2,5
vaus_oam_data:
  .byte VAUS_Y + 4 - 1, $05, $01, $FF  ; OAM+0: current position
  .byte $FF,            $07, $00, 152  ; OAM+4: fire button
  .byte VAUS_Y + 4 - 1, $06, $00, $FF  ; OAM+8: left side of range
  .byte VAUS_Y + 4 - 1, $06, $40, $FF  ; OAM+12: right side of range
vaus_oam_data_end:

; Menu ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.code
.if 0
.proc do_input_unfinished
  ldx #helpsect_under_construction
  lda #KEY_A|KEY_B|KEY_START
  jsr helpscreen
  ; fall through to input unfinished
.endproc
.endif

.proc do_input_test
  jsr read_pads  ; read them once because B to exit may double trigger
  ldy #$FF
  jsr pads_play_semitone_y
  ldx #helpsect_input_test_menu
  lda #KEY_A|KEY_B|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  jsr helpscreen

  lda new_keys+0
  and #KEY_A
  beq not_input_test
    tya
    asl a
    tay
    lda input_tests+1,y
    pha
    lda input_tests+0,y
    pha
    rts
  not_input_test:

  lda #helpsect_input_test
  jsr helpcheck
  bcs do_input_test
  lda new_keys+0
  and #KEY_B
  beq do_input_test
  rts
.endproc

.rodata
input_tests:
  .addr do_serial_analyzer-1
  .addr do_fcpads_test-1
  .addr do_fourscore_test-1
  .addr do_zapper_test-1
  .addr do_power_pad_test-1
  .addr do_vaus_test-1
  .addr do_snes_pad_test-1
  .addr do_mouse_test-1
