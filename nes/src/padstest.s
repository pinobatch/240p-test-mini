.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_input_test_menu, helpsect_input_test
.importzp helpsect_under_construction
.importzp RF_serial_analyzer

; 8 activities within padstest (issue #42)
; - [X] 10-channel serial analyzer
; - [ ] Standard controller 1 and 2, Famicom expansion controllers,
;       and microphone
; - [ ] NES Four Score
; - [X] Zapper (move Zapper test to this submenu)
; - [ ] Power Pad for NES
; - [ ] Arkanoid controller for NES
; - [ ] Super NES controller
; - [ ] Super NES Mouse


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
  .addr do_input_unfinished-1
  .addr do_input_unfinished-1
  .addr do_zapper_test-1
  .addr do_input_unfinished-1
  .addr do_input_unfinished-1
  .addr do_input_unfinished-1
  .addr do_input_unfinished-1

; Serial analyzer ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NUM_READS = 32
NUM_PORTS = 2
BITS_PER_PORT = 5
LA_NUM_CHANNELS = NUM_PORTS * BITS_PER_PORT

serial_read_data0 = OAM
serial_read_data1 = serial_read_data0 + NUM_READS
serial_disp_data = serial_read_data1 + NUM_READS
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
  exit_time = test_state + 0
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

