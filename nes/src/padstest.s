.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_input_test_menu, helpsect_input_test
.importzp helpsect_under_construction
.importzp RF_serial_analyzer, RF_input_fcpads, RF_input_fourscore
.importzp RF_input_power_pad, RF_input_snes_pad

; Remaining activities within padstest (issue #42)
; - [ ] Arkanoid controller for NES
; - [ ] Super NES Mouse

exit_time = test_state + 0
buttonset = test_state + 1

.code
; Menu ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc do_input_unfinished
  ldx #helpsect_under_construction
  lda #KEY_A|KEY_B|KEY_START
  jsr helpscreen
  ; fall through to input unfinished
.endproc

.proc do_input_test
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

input_tests:
  .addr do_serial_analyzer-1
  .addr do_fcpads_test-1
  .addr do_fourscore_test-1
  .addr do_zapper_test-1
  .addr do_power_pad_test-1
  .addr do_input_unfinished-1  ; TODO: Arkanoid
  .addr do_snes_pad_test-1
  .addr do_input_unfinished-1  ; TODO: SNES Mouse

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
    lda $4016
    sta serial_read_data0,x
    lda $4017
    sta serial_read_data1,x
    inx
    cpx #NUM_READS
    bcc readloop
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
  lda nmis
  :
    cmp nmis
    beq :-
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

.proc load_std_controller_images
  lda #13
.endproc
.proc load_controller_images_A
  ldx #VBLANK_NMI
  stx help_reload
  stx PPUCTRL
  ldy #0
  sty PPUMASK
  ldx #$08
  stx exit_time
  jsr unpb53_file
  ldx #$00
  stx PPUADDR
  stx PPUADDR
  lda #$20
  chrloop:
    lda controller_test_obj_chr,x
    sta PPUDATA
    inx
    cpx #controller_test_obj_chr_end-controller_test_obj_chr
    bne chrloop

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
read_data_offset = $05
mask = $04
yoffset = $03
xypos_offset = $02
count = $01

  ldy #5
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
      inx
    next_obj:
    inc read_data_offset
    inc xypos_offset
    dec count
    bne buttonloop
  stx oam_used
  ldx setdef_offset
  lda button_sets_base,x
  bpl nes_buttons_draw_obj
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
    lda nmis
    :
      cmp nmis
      beq :-
    ldx #0
    stx OAMADDR
    lda #>OAM
    sta OAM_DMA
    ldy #0
    lda #VBLANK_NMI|BG_0000|OBJ_0000
    sec
    jsr ppu_screen_on
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

controller_test_palette:
  .byte $0F,$20,$28,$16  ; Text and FC
  .byte $0F,$00,$10,$16  ; NES
  .byte $0F,$00,$10,$13  ; Super NES
  .byte $0F,$12,$16,$10  ; power pad
controller_test_palette_end:

controller_test_obj_chr:
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $38, $7C, $FE, $FE, $FE, $FE, $7C, $38
  .byte $38, $44, $82, $82, $82, $82, $44, $38
controller_test_obj_chr_end:

; serial_read_data0 offset, mask, Y offset, xypos offset, count
button_sets_base:
fcpads_button_sets:
  .byte  0, $01,   0, nes_button_xpos-button_xpos_base, 8
  .byte 32, $01,  40, nes_button_xpos-button_xpos_base, 8
  .byte  0, $02,  80, nes_button_xpos-button_xpos_base, 8
  .byte 32, $02, 120, nes_button_xpos-button_xpos_base, 8
  .byte  0, $04,   0, fc_mic_xpos-button_xpos_base, 1
  .byte $FF
fourscore_button_sets:
  .byte  0, $01,   0, nes_button_xpos-button_xpos_base, 8
  .byte  8, $01,  80, nes_button_xpos-button_xpos_base, 8
  .byte 16, $01, 112, fourscore_sig_xpos-button_xpos_base, 8
  .byte 32, $01,  40, nes_button_xpos-button_xpos_base, 8
  .byte 40, $01, 120, nes_button_xpos-button_xpos_base, 16
  .byte $FF
snes_pad_button_sets:
  .byte  0, $01,  40, snes_button_xpos-button_xpos_base, 12
  .byte 32, $01,  80, snes_button_xpos-button_xpos_base, 12
  .byte $FF
first_non_selectstart_button_set:
power_pad_button_sets:
  .byte 32, $08,   0, power_pad_xpos-button_xpos_base, 8
  .byte 32, $10,   0, power_pad_d4_xpos-button_xpos_base, 4
  .byte $FF

button_xpos_base:
nes_button_xpos:
  .byte 147, 137, 118, 126, 104, 104,  99, 109
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