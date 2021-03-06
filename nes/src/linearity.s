.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_linearity

lcdc_value = test_state+0

.segment "CODE02"

.proc do_new_linearity
  lda #VBLANK_NMI|BG_0000
  sta PPUCTRL
  sta lcdc_value
  sta help_reload
  asl a
  sta PPUMASK
  jsr rf_load_yrgb_palette

  ; clear tiles and tilemap
  lda #$00
  tay
  tax
  jsr ppu_clear_nt
  jsr linearity_clear_grid

  ; Load new Copy grid to other PRG ROM bank
  lda tvSystem
  cmp #1
  lda #0>>1  ; iu53 file 0: NTSC; file 1: PAL
  rol a
  jsr load_iu53_file

  ; Copy grid to other PRG ROM bank
  jsr add_grid

forever:
  jsr ppu_wait_vblank
  lda lcdc_value
  clc
  jsr ppu_screen_on_xy0
  
  lda #helpsect_linearity
  jsr read_pads_helpcheck
  bcs do_new_linearity
  lda new_keys
  and #KEY_A
  beq not_toggle_grid
    lda #BG_1000
    eor test_state
    sta test_state
  not_toggle_grid:
  lda new_keys
  and #KEY_B
  beq forever
  rts
.endproc

.segment "CODE02"

.proc linearity_clear_grid
  lda tvSystem
  bne is_pal
  
  lda #VBLANK_NMI|VRAM_DOWN
  sta PPUCTRL
  ldx #31
  lda #3
  colloop:
    ldy #$20
    sty PPUADDR
    stx PPUADDR
    ldy #30
    byteloop:
      sta PPUDATA
      dey
      bne byteloop
    sec
    sbc #1
    bcs :+
      lda #6
    :
    dex
    bpl colloop
  jmp clear_attr
is_pal:
rowsleft = $00
  lda #VBLANK_NMI
  sta PPUCTRL

  ; Preload grid tiles for blank rows because they appear out of order
  ldx #$10
  stx PPUADDR
  asl a
  sta PPUADDR
  sta rowsleft
  paltileloop:
    ldx #8
    lda #0
    palp0loop:
      sta PPUDATA
      dex
      bne palp0loop
    ldy rowsleft
    iny
    sty rowsleft
    ldx #8
    palp1loop:
      lda #$80
      dey
      bne :+
        lda #$FF
      :
      sta PPUDATA
      dex
      bne palp1loop
    ldy rowsleft
    cpy #9
    bcc paltileloop

  ; Now we can get to the map
  lda #$20
  sta PPUADDR
  ldy #$00
  sty PPUADDR
  lda #30
  sta rowsleft

  rowloop:
    
    ldx #32
    lda gridpatterns_y,y
    pal_byteloop:
      sta PPUDATA
      dex
      bne pal_byteloop
    iny
    cpy #11
    bcc :+
      ldy #0
    :
    dec rowsleft
    bne rowloop
clear_attr:
  ldx #64
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  attrloop:
    sta PPUDATA
    dex
    bne attrloop
  rts
.endproc

.proc add_grid
last_tileid = $00
xpatternindex = $01
ypatternindex = $03
widcd = $04
tilebuf = help_line_buffer
gridpattern = help_line_buffer + 16

  ; Seek to top of screen
  lda #$20  ; DEBUG: change to $20
  sta ciSrc+1
  lda #$00
  sta ciSrc+0
  sta last_tileid
  lda #7
  sta xpatternindex
  ldy #15-11
  lda tvSystem
  beq :+
    ldy #0
  :
  sty ypatternindex

  rowloop:
    lda #32
    sta widcd
    lda #7
    sta xpatternindex
    ldx #4
    
    tileloop:
      lda tvSystem
      bne tilestart_not_ntsc
        inc xpatternindex
        lda xpatternindex
        cmp #7
        bcc tilestart_not_ntsc
        lda #0
        sta xpatternindex
      tilestart_not_ntsc:
      ; Read the tile number from the nametable
      lda ciSrc+1
      sta PPUADDR
      lda ciSrc+0
      sta PPUADDR
      bit PPUDATA
      lda PPUDATA

      ; Process only if at least as far into PT as the last tile
      cmp last_tileid
      bcc skip_this_tile
        jsr build_this_tile
      skip_this_tile:
      inc ciSrc+0
      bne :+
        inc ciSrc+1
      :
      dec widcd
      bne tileloop

    ; Move to next pattern row only on PAL
    lda tvSystem
    beq rowend_not_pal
      inc ypatternindex
      lda ypatternindex
      cmp #11
      bcc rowend_not_pal
      lda #0
      sta ypatternindex
    rowend_not_pal:

    ; If at end of nametable, stop
    lda ciSrc+0
    cmp #$C0
    lda ciSrc+1
    sbc #$23
    bcc rowloop
  rts

build_this_tile:
  sta last_tileid

  ; Calculate address of this tile
  asl a
  sta ciDst+0
  lda #0
  tay
  rol a
  asl ciDst+0
  rol a
  asl ciDst+0
  rol a
  asl ciDst+0
  rol a
  sta ciDst+1
  sta PPUADDR
  lda ciDst+0
  sta PPUADDR
  bit PPUDATA

  ; Read the tile back
  readbackloop:
    lda PPUDATA
    sta tilebuf,y
    iny
    cpy #16
    bcc readbackloop
  
  ; Construct the grid pattern
  ldy xpatternindex
  lda gridpatterns_x,y
  ldy #7
  buildloop:
    sta gridpattern,y
    dey
    bpl buildloop
  ldy ypatternindex
  lda gridpatterns_y,y
  cmp #8
  bcs nohbar
    tay
    lda #$FF
    sta gridpattern,y
  nohbar:

  ; Apply the grid pattern
  ldy #7
  applyloop:
    lda tilebuf,y
    eor tilebuf+8,y
    and gridpattern,y
    eor tilebuf,y
    sta tilebuf,y
    lda tilebuf+8,y
    ora gridpattern,y
    sta tilebuf+8,y
    dey
    bpl applyloop
  
  
  ; Write the updated tile
  lda ciDst+1
  ora #$10
  sta PPUADDR
  lda ciDst+0
  sta PPUADDR
  ldy #0
  writebackloop:
    lda tilebuf,y
    sta PPUDATA
    iny
    cpy #16
    bcc writebackloop
  rts
.endproc

.rodata
gridpatterns_x:
  .byte %00100000  ; NTSC: 0-6
  .byte %01000000
  .byte %10000001
  .byte %00000010
  .byte %00000100
  .byte %00001000
  .byte %00010000
  .byte %10000000  ; PAL: 7

gridpatterns_y:
  .byte 8,2,5,8,0,3,6,8,1,4,7  ; PAL: 0-10; NTSC: 4
