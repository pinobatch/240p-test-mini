.include "nes.inc"
.include "global.inc"
.export nmi_handler

OAM = $0200
SIZEOF_LINEBUF = 28
MDFBUF_MAX = 64

.bss
; Bit 7-1 of each entry gives what character to write
ppu_linebuf: .res SIZEOF_LINEBUF

.zeropage
ppu_cursor_x: .res 1
ppu_cursor_y: .res 1
ppu_yscroll: .res 1
ppu_row_to_push: .res 1
nmis: .res 1
mdfourier_addrdata: .res 3*MDFBUF_MAX+2

.segment "LOWCODE"

.proc ppu_cls
  jsr ppu_clear_linebuf
  lda #240-24  ; top of screen
  sta ppu_yscroll
  sta ppu_row_to_push
  ldy #0
  sty ppu_cursor_y
  sty mdfourier_addrdata+1
  sty PPUMASK
  ldx #$20
  lda #$40
  ; fall through to ppu_clear_nt
.endproc

;;
; Clears a nametable to a given tile number and attribute value.
; (Turn off rendering in PPUMASK and set the VRAM address increment
; to 1 in PPUCTRL first.)
; @param A tile number
; @param X base address of nametable ($20, $24, $28, or $2C)
; @param Y attribute value ($00, $55, $AA, or $FF)
.proc ppu_clear_nt

  ; Set base PPU address to XX00
  stx PPUADDR
  ldx #$00
  stx PPUADDR

  ; Clear the 960 spaces of the main part of the nametable,
  ; using a 4 times unrolled loop
  ldx #960/4
loop1:
  .repeat 4
    sta PPUDATA
  .endrepeat
  dex
  bne loop1

  ; Clear the 64 entries of the attribute table
  ldx #64
loop2:
  sty PPUDATA
  dex
  bne loop2
  rts
.endproc

;;
; Moves all sprites starting at address X (e.g, $04, $08, ..., $FC)
; below the visible area.
; X is 0 at the end.
.proc ppu_clear_oam

  ; First round the address down to a multiple of 4 so that it won't
  ; freeze should the address get corrupted.
  txa
  and #%11111100
  tax
  lda #$FF  ; Any Y value from $EF through $FF will work
loop:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne loop
  rts
.endproc

; Terminal emulation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc ppu_puts_ay
  sta $01
  sty $00
.endproc
.proc ppu_puts_0
  ldy #0
  beq nextchar
  is_char:
    jsr ppu_putchar
    iny
    bne nextchar
    inc $01
  nextchar:
    lda ($00),y
    bne is_char
  tya
  clc
  adc $00
  sta $00
  bcc :+
    inc $01
  :
  rts
.endproc

;;
; Writes the character in A to to the screen.
; Trashes AX, preserves Y
.proc ppu_putchar
  ; Write character if printable
  cmp #$20
  bcc is_control_character
    pha
    ; Printable character.  If this line is full, make a new line
    ldx ppu_cursor_x
    cpx #SIZEOF_LINEBUF
    bcc not_overflow
      jsr ppu_newline
    not_overflow:

    ; If there's a row to push that's not this one, push it first
    lda ppu_row_to_push
    bmi push_ok
    cmp ppu_cursor_y
    beq push_ok
      jsr ppu_wait_vblank
    push_ok:
    pla

    ; Finally ready to write the character
    ldx ppu_cursor_x
    asl a
    sta ppu_linebuf,x
    inx
    stx ppu_cursor_x
    lda ppu_cursor_y
    sta ppu_row_to_push
    rts
  is_control_character:

  ; Otherwise, for now, treat all control characters as newline
.endproc

.proc ppu_newline
  lda ppu_row_to_push
  bmi :+
    jsr ppu_wait_vblank
  :
  inc ppu_cursor_y
  lda ppu_cursor_y
  cmp #15
  bcc :+
    lda #0
    sta ppu_cursor_y
  :
  sta ppu_row_to_push
  ; fall through to ppu_clear_linebuf
.endproc

.proc ppu_clear_linebuf
  ldx #SIZEOF_LINEBUF - 1
  lda #$40
  :
    sta ppu_linebuf,x
    dex
    bpl :-
  inx
  stx ppu_cursor_x
  rts
.endproc

; Vblank handler (eventually) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc nmi_handler
  inc nmis
  rti
.endproc

.proc ppu_wait_vblank
  tya
  pha

  ldx #0
  lda nmis
  :
    cmp nmis
    beq :-

  ; Flush audio writes
  bne first
  stillgoing:
    lda mdfourier_addrdata+2,x
    sta (mdfourier_addrdata,x)
    inx
    inx
    inx
  first:
    lda mdfourier_addrdata+1,x
    bne stillgoing
  sta mdfourier_addrdata+1

  ; Do vblank things
  jsr ppu_push
  ldx #0
  ldy ppu_yscroll
  lda #VBLANK_NMI
  clc  ; sprites not yet used
  jsr ppu_screen_on
  pla
  tay
  rts
.endproc

;;
; Sets the scroll position and turns PPU rendering on.
; @param A value for PPUCTRL ($2000) including scroll position
; MSBs; see nes.inc
; @param X horizontal scroll position (0-255)
; @param Y vertical scroll position (0-239)
; @param C if true, sprites will be visible
.proc ppu_screen_on
  stx PPUSCROLL
  sty PPUSCROLL
  sta PPUCTRL
  lda #BG_ON
  bcc :+
  lda #BG_ON|OBJ_ON
:
  sta PPUMASK
  rts
.endproc

; this should eventually be rolled into the NMI handler
.proc ppu_push
  lda ppu_row_to_push
  bpl :+
    rts
  :
  lsr a
  ror a
  tax
  and #$03
  ora #$20
  sta PPUADDR
  txa
  ror a
  and #$C0
  sta PPUADDR
  ldx #0
  loop:
    bit PPUDATA
    bit PPUDATA
    ldy #0
    yloop:
      .repeat 4
        txa
        ora ppu_linebuf,y
        iny
        sta PPUDATA
      .endrepeat
      cpy #SIZEOF_LINEBUF
      bcc yloop
    bit PPUDATA
    bit PPUDATA
    inx
    cpx #2
    bcs :+
      jmp loop
    :

  ; TODO: If pushed row is in the overscan, scroll until it isn't
  lda ppu_row_to_push
  asl a
  asl a
  asl a
  asl a
  tax  ; X = Y coordinate of top of pushed orow
  sbc ppu_yscroll
  bcs :+
    adc #240
  :
  cmp #16
  bcc is_offscreen
  cmp #240-32
  bcc not_offscreen
  is_offscreen:
    txa
    sbc #240-32
    bcs :+
      adc #240
    :
    sta ppu_yscroll
  not_offscreen:

  sec
  ror ppu_row_to_push
  rts
.endproc
