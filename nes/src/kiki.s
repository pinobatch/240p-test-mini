.include "nes.inc"
.include "global.inc"
.importzp helpsect_vertical_scroll_test

.segment "GATEDATA"
kikimap_pb53:
  .incbin "obj/nes/kikimap.chr.pb53"

.rodata

; Metatiles:
; 0 sand
; 1 path
; 2 wall top
; 3 wall front
; 4 wall shadow (top right corner)
; 5 wall shadow (top)
; 6 wall shadow (top left corner)
; 7 wall shadow (left)
; 8 wall shadow (bottom left corner)
; 9 wall shadow (top and left)
; Metatile defs
mt_tl:    .byte $00,$04,$01,$0c,$11,$13,$13,$13,$12,$13
mt_bl:    .byte $02,$05,$01,$0d,$02,$02,$02,$13,$13,$13
mt_tr:    .byte $02,$06,$03,$0e,$13,$13,$02,$02,$02,$13
mt_br:    .byte $00,$07,$03,$0f,$00,$00,$00,$00,$00,$00
mt_attr:  .byte $00,$80,$80,$80,$00,$00,$00,$00,$00,$00
mt_below: .byte   0,  0,  3,  4,  0,  0,  0,  6,  6,  6
mt_belowR:.byte   8,  0,  3,  9,  0,  0,  0,  7,  7,  7

kiki_palette:
  .byte $0F,$07,$17,$27
  .byte $0F,$00,$1A,$10
  .byte $0F,$00,$1A,$10

.code

hw_yscroll_lo = test_state+10
hw_yscroll_hi = test_state+11
.proc do_vscrolltest

  ; Initialize speed control
  lda #1
  sta hill_zone_speed  
  lsr a
  sta hill_zone_xlo
  sta hill_zone_xhi
  sta hill_zone_dir

restart:
  lda #VBLANK_NMI
  sta PPUCTRL
  sta help_reload
  asl a
  sta PPUMASK
  
  ; Load tiles
  tax
  tay
  lda #$03
  jsr unpb53_file

:
  lda #GATEDATA_BANK
  sta :- + 1
  jsr load_kiki_map

  ; load palette
  ldx #$3F
  stx PPUADDR
  lda #0
  sta PPUADDR
  tax
  :
    lda kiki_palette,x
    sta PPUDATA
    inx
    cpx #12
    bcc :-
  
  ; Set up sprite 0
  ldx #4
  jsr ppu_clear_oam
  lda #$10
  sta OAM+1
  lda #$20  ; behind background
  sta OAM+2
  lda #144
  sta OAM+3

forever:

  ; Wrap scrolling within 0-959 half-scanlines
  lda hill_zone_xlo
  ldy hill_zone_xhi
  bpl notneg
    clc
    adc #<960
    tax
    lda hill_zone_xhi
    adc #>960
    jmp have_corrected_x
  notneg:
  sec
  sbc #<960
  tax
  tya
  sbc #>960
  bcc notover960
  have_corrected_x:
    stx hill_zone_xlo
    sta hill_zone_xhi
  notover960:

  ; Convert 0-959 to nametable and Y scroll
  lda hill_zone_xhi
  lsr a
  sta hw_yscroll_hi
  lda hill_zone_xlo
  ror a
  sta hw_yscroll_lo
  sec
  sbc #240
  tax
  lda hw_yscroll_hi
  sbc #$00
  bcc :+
    stx hw_yscroll_lo
  :
  lda #(VBLANK_NMI|BG_0000) >> 1
  rol a
  sta hw_yscroll_hi

  ; Move sprite 0
  lda #238
  sec
  sbc hw_yscroll_lo
  sta OAM+0
  bcs not_bad_s0
    lda hw_yscroll_hi
    eor #$01
    sta hw_yscroll_hi
  not_bad_s0:

  lda nmis
:
  cmp nmis
  beq :-
  ldx #0
  stx OAMADDR
  lda #>OAM
  sta OAM_DMA
  ldy hw_yscroll_lo
  lda hw_yscroll_hi
  sec
  jsr ppu_screen_on

  lda #helpsect_vertical_scroll_test
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  jsr hill_zone_speed_control
  
  ; switch after sprite 0
  lda hw_yscroll_lo
  cmp #239
  bcs nos0wait

  lda hw_yscroll_hi
  eor #$01
  tax
  lda #$C0
  :
    bit PPUSTATUS
    bvs :-
  :
    bit PPUSTATUS
    beq :-
  stx PPUCTRL
  nos0wait:

  lda #KEY_B
  and new_keys
  bne done
  jmp forever
done:
  rts
.endproc

wallbits_L = $0100
wallbits_R = $0120
pathbits_L = $0140
pathbits_R = $0160
mt_row = $0180
attrbuf = $0190

.proc load_kiki_map
mtdstlo = $00
mtdsthi = $01
attrdst = $02
mapsrc = $03

  ; Decompress map
  lda #<(kikimap_pb53 + 2)
  sta ciSrc+0
  lda #>(kikimap_pb53 + 2)
  sta ciSrc+1
  lda #128
  sta ciBufEnd
  asl a
  sta ciBufStart
  jsr unpb53_gate

  ; Clear metatile buffer
  lda #$20
  sta mtdsthi
  lda #$00
  sta mapsrc
  ldx #15
  :
    sta mt_row,x
    dex
    bpl :-

  scrnloop:
    lda #0
    sta mtdstlo
    lda #$C0
    sta attrdst
  ; Render row of metatiles
  rowloop:
    ldx mapsrc
    jsr decode_one_row
  
    ; Copy to nametable
    lda mtdsthi
    sta PPUADDR
    lda mtdstlo
    sta PPUADDR
    clc
    adc #64
    sta mtdstlo
    bcc :+
      inc mtdsthi
    :
    jsr render_metatile_row
    jsr accum_attr_row
    lda mtdstlo
    and #64
    bne :+
      lda attrdst
      tay
      clc
      adc #8
      sta attrdst
      lda mtdsthi
      jsr push_attr_row
    :
    inc mapsrc
    lda mapsrc
    cmp #15
    bne @not15
      jsr extra_attr_row
      inc mtdsthi
      jmp scrnloop
    @not15:
    cmp #30
    bcc rowloop

extra_attr_row:
  jsr accum_attr_row
  ldy attrdst
  lda mtdsthi
  jmp push_attr_row
.endproc

.proc decode_one_row
wall_L = $04
wall_R = $05
path_L = $06
path_R = $07
tiletotopleft = $04

  ; Load decompressed map
  lda wallbits_L,x
  pha
  lda wallbits_R,x
  sta wall_R
  lda pathbits_L,x
  sta path_L
  lda pathbits_R,x
  sta path_R

  ; Find most common tile below
  ldx #0
  stx tiletotopleft
  mcbelow_loop:
    ldy mt_row,x
    cmp #3
    bne @not_wallfront
      lda mt_belowR,y
      bcs @mcbelow_have
    @not_wallfront:
      lda mt_below,y
      cmp #4
      bne @mcbelow_have
      lda tiletotopleft
      cmp #3
      bne @not4to5
        lda #5
        bne @mcbelow_have
      @not4to5:
      lda #4
    @mcbelow_have:
    sty tiletotopleft
    sta mt_row,x
    inx
    cpx #16
    bcc mcbelow_loop

  pla
  sta wall_L
  ldx #15
  replaceloop:
    lda mt_row,x
    lsr wall_L
    ror wall_R
    bcc :+
      lda #2
    :
    lsr path_L
    ror path_R
    bcc :+
      lda #1
    :
    sta mt_row,x
    dex
    bpl replaceloop
  rts
.endproc

.proc render_metatile_row
  ldx #0
  toprowloop:
    ldy mt_row,x
    lda mt_tl,y
    sta PPUDATA
    lda mt_tr,y
    sta PPUDATA
    inx
    cpx #16
    bcc toprowloop
  ldx #0
  bottomrowloop:
    ldy mt_row,x
    lda mt_bl,y
    sta PPUDATA
    lda mt_br,y
    sta PPUDATA
    inx
    cpx #16
    bcc bottomrowloop
  rts
.endproc

.proc accum_attr_row
srcx = $06
dstx = $07
  ldx #0
  stx srcx
  loop:
    stx dstx
    lda attrbuf,x
    ldx srcx
    .repeat 2
      ldy mt_row,x
      inx
      lsr a
      lsr a
      ora mt_attr,y
    .endrepeat
    stx srcx
    ldx dstx
    sta attrbuf,x
    inx
    cpx #8
    bcc loop
  rts
.endproc

.proc push_attr_row
  ora #$03
  sta PPUADDR
  sty PPUADDR
  ldx #0
  :
    lda attrbuf,x
    sta PPUDATA
    inx
    cpx #8
    bcc :-
  rts
.endproc

