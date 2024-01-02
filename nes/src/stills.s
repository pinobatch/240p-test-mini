;
; Still screens for 240p test suite
; Copyright 2015-2023 Damian Yerrick
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
.importzp helpsect_monoscope, helpsect_sharpness, helpsect_ire
.importzp helpsect_smpte_color_bars, helpsect_color_bars_on_gray
.importzp helpsect_pluge, helpsect_gradient_color_bars
.importzp helpsect_gray_ramp, helpsect_color_bleed
.importzp helpsect_full_screen_stripes, helpsect_solid_color_screen
.importzp helpsect_chroma_crosstalk, helpsect_convergence
.importzp RF_ire, RF_smpte, RF_cbgray, RF_pluge
.importzp RF_gcbars, RF_gcbars_labels, RF_gcbars_grid, RF_cpsgrid_224
.importzp RF_cpsgrid_240, RF_gray_ramp, RF_bleed, RF_fullstripes
.importzp RF_solid

; sb53-based stills ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.rodata
; To allow set-and-forget palette management, sharpness bricks do not
; share color 0 with the main pattern.  This means they use
; colors 5, 6, 7, not 0, 1, 2.
bricks_tile:
  .byte %11000000
  .byte %00110000
  .byte %00001100
  .byte %10000111
  .byte %11100011
  .byte %00110111
  .byte %00001111
  .byte %00000011

  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %01111011
  .byte %11011101
  .byte %11111001
  .byte %11111101
  .byte %11111111

monoscope_fglevels:
  .byte $0F,$00,$10,$20,$20
monoscope_fglevels_end:
monoscope_bglevels:
  .byte $0F,$0F,$0F,$0F,$00

xtalk_word_shape:
  .byte %01111111
  .byte %01111111
  .byte %00001110
  .byte %00011100
  .byte %00111000
  .byte %01111111
  .byte %01111111
  .byte %00000000
  .byte %00000001
  .byte %00000001
  .byte %01111111
  .byte %01111111
  .byte %00000001
  .byte %00000001
  .byte %00000000
  .byte %00100110
  .byte %01001111
  .byte %01001101
  .byte %01011001
  .byte %01111001
  .byte %00110010
  .byte %00000000
  .byte %00111110
  .byte %01111111
  .byte %01000001
  .byte %01000001
  .byte %01100011
  .byte %00100010
xtalk_word_shape_end:

XTALK_STRIPE_TL = $2160
XTALK_STRIPE_HT = 9
XTALK_PHASES = 3
XTALK_WORD_TL = XTALK_STRIPE_TL + 32 + 2

.zeropage
test_state: .res SIZEOF_TEST_STATE

.segment "CODE"

.proc do_sharpness
  lda #VBLANK_NMI
  sta test_state
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK

  ; Load main nametable, plus main and bricks palettes
  ldx #$20
  lda #$00
  tay
  jsr ppu_clear_nt
  tax
  jsr ppu_clear_nt
  lda #2
  jsr load_iu53_file

  ; Load bricks tile
  ldx #$24
  lda #$FF
  ldy #$55
  jsr ppu_clear_nt
  lda #$0F
  sta PPUADDR
  lda #$F0
  sta PPUADDR
  ldx #$00
  brickloop1:
    lda bricks_tile,x
    sta PPUDATA
    inx
    cpx #16
    bcc brickloop1

loop:
  jsr ppu_wait_vblank
  lda test_state
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_sharpness
  jsr read_pads_helpcheck
  bcs do_sharpness
  lda new_keys
  and #KEY_A
  beq not_toggle_bricks
    lda #1
    eor test_state
    sta test_state
  not_toggle_bricks:
  lda new_keys
  and #KEY_B
  beq loop
  rts
.endproc

.proc do_monoscope
  lda #1
  sta test_state
restart:
  lda #VBLANK_NMI
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK

  ; Load main nametable for this TV system
  ldx #$20
  lda #$00
  tay
  jsr ppu_clear_nt
  tax
  jsr ppu_clear_nt

  lda tvSystem
  beq :+
    lda #1
  :
  jsr load_iu53_file

loop:
  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldy test_state
  lda monoscope_bglevels,y
  sta PPUDATA
  lda monoscope_fglevels,y
  sta PPUDATA
  lda #$16
  sta PPUDATA

  lda #VBLANK_NMI
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_monoscope
  jsr read_pads_helpcheck
  bcs restart

  ; Adjust brightness up or down, wrapping
  ldy test_state
  lda new_keys
  and #KEY_UP|KEY_RIGHT
  beq not_inc_brightness
    iny
    cpy #monoscope_fglevels_end-monoscope_fglevels
    bcc not_inc_brightness
    ldy #0
  not_inc_brightness:
  lda new_keys
  and #KEY_DOWN|KEY_LEFT
  beq not_dec_brightness
    dey
    bpl not_dec_brightness
    ldy #monoscope_fglevels_end-monoscope_fglevels-1
  not_dec_brightness:
  sty test_state

  lda new_keys
  and #KEY_B
  beq loop
no_flashing_please:
  rts
.endproc

.proc do_crosstalk
palette_base = test_state + 0

  jsr flashing_consent
  beq do_monoscope::no_flashing_please

  ; To delete: iu53 file 4
  lda #VBLANK_NMI
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK

  ; load bg
  tay
  tax
  jsr ppu_clear_nt
  ldx #$20
  jsr ppu_clear_nt

  ; Load pattern table
  sta PPUADDR
  lda #$10
  sta PPUADDR
  lda #%11011011
  clc
  ldx #16*3
  pt_byteloop:
    sta PPUDATA
    ror a
    dex
    bne pt_byteloop

  ; Write background pattern
  ldx #>XTALK_STRIPE_TL
  stx PPUADDR
  ldx #<XTALK_STRIPE_TL
  stx PPUADDR
  ldx #32 * XTALK_STRIPE_HT / 3
  clr3loop:
    ldy #1
    clr1loop:
      sty PPUDATA
      iny
      cpy #XTALK_PHASES+1
      bcc clr1loop
    dex
    bne clr3loop

  ; Write word
colphase = $00

  ldy #VBLANK_NMI|VRAM_DOWN
  sty PPUCTRL
  ldy #3
  sty colphase
  ldy #xtalk_word_shape_end-xtalk_word_shape-1
  colloop:
    ldx colphase
    dex
    bne :+
      ldx #XTALK_PHASES
    :
    stx colphase
    lda #>XTALK_WORD_TL
    sta PPUADDR
    tya
    clc
    adc #<XTALK_WORD_TL
    sta PPUADDR
    lda xtalk_word_shape,y
    bitloop:
      lsr a
      pha
      txa
      adc #0
      cmp #XTALK_PHASES+1
      bcc :+
        lda #1
      :
      sta PPUDATA
      dex
      bne :+
        ldx #XTALK_PHASES
      :
      pla
      bne bitloop
    dey
    bpl colloop

  lda #$16
  sta palette_base

loop:
  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  lda #$01
  sta PPUADDR
  lda palette_base
  sta PPUDATA
  ldx #2
  palloop:
    clc
    adc #4
    cmp #$1D
    bcc :+
      sbc #$0C
    :
    sta PPUDATA
    dex
    bne palloop
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_chroma_crosstalk
  jsr read_pads_helpcheck
  bcc :+
    jmp do_crosstalk
  :

  ; Step the colors once every 16 frames, cycling once every 192
  lda nmis
  and #$0F
  bne noinccolor
    ldy palette_base
    iny
    cpy #$1D
    bcc :+
      ldy #$11
    :
    sty palette_base
  noinccolor:

  lda new_keys
  and #KEY_B
  beq loop
  rts
.endproc

; IRE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"

ire_msgs2:
  .byte ire_msg00-ire_msgbase,   ire_msg0D-ire_msgbase
  .byte ire_msg10-ire_msgbase,   ire_msg1D-ire_msgbase
  .byte ire_msg20-ire_msgbase,   ire_msg2D-ire_msgbase
  .byte ire_msg30-ire_msgbase,   ire_msg3D-ire_msgbase
  .byte ire_msg00em-ire_msgbase, ire_msg0Dem-ire_msgbase
  .byte ire_msg10em-ire_msgbase, ire_msg1Dem-ire_msgbase
  .byte ire_msg20em-ire_msgbase, ire_msg2Dem-ire_msgbase
  .byte ire_msg30em-ire_msgbase, ire_msg3Dem-ire_msgbase

; Using lidnariq's measurements from
; http://wiki.nesdev.com/w/index.php/NTSC_video#Terminated_measurement
ire_msgbase:
ire_msg00:   .byte "43",0
ire_msg10:   .byte "74",0
ire_msg20:
ire_msg30:   .byte "110",0
ire_msg0D:   .byte "-12",0
ire_msg1D:   .byte "0", 0
ire_msg2D:   .byte "34",0
ire_msg3D:   .byte "80",0
ire_msg00em: .byte "26",0
ire_msg10em: .byte "51",0
ire_msg20em:
ire_msg30em: .byte "82",0
ire_msg0Dem: .byte "-17",0
ire_msg1Dem: .byte "-8",0
ire_msg2Dem: .byte "19",0
ire_msg3Dem: .byte "56",0
ire_sepmsg:  .byte "on",0

irelevel_bg: .byte $0D,$1D,$1D,$1D,$1D, $1D,$1D,$00,$10,$20
irelevel_fg: .byte $1D,$1D,$2D,$00,$10, $3D,$20,$20,$20,$20
NUM_IRE_LEVELS = * - irelevel_fg

.segment "CODE"
ire_emph = test_state+3
.proc do_ire
ire_level = test_state+0
need_reload = test_state+1
disappear_time = test_state+2

  lda #6
  sta ire_level
  lda #0
  sta ire_emph
restart:
  jsr rf_load_tiles
  lda #$20
  sta need_reload
  lda #RF_ire
  jsr rf_load_layout

loop:
  lda need_reload
  beq not_reloading
    lda #0
    sta need_reload
    lda #120
    sta disappear_time
    jsr clearLineImg

    ; Draw foreground level
    ldx ire_level
    lda irelevel_fg,x
    jsr ire_get_msgbase
    jsr vwfStrWidth
    sec
    eor #$FF
    adc #24
    tax
    jsr vwfPuts0

    ; Draw background level
    lda #>ire_sepmsg
    ldy #<ire_sepmsg
    ldx #27
    jsr vwfPuts
    ldx ire_level
    lda irelevel_bg,x
    jsr ire_get_msgbase
    ldx #40
    jsr vwfPuts

    ; Prepare for blitting
    lda #%0111
    jsr rf_color_lineImgBuf
    lda #$0F
    sta vram_copydsthi
    lda #$80
    sta vram_copydstlo
  not_reloading:

  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx ire_level
  ldy irelevel_bg,x
  sty PPUDATA
  lda disappear_time
  beq :+
    ldy #$02
  :
  sty PPUDATA
  beq :+
    ldy #$38
    dec disappear_time
  :
  sty PPUDATA
  ldy irelevel_fg,x
  sty PPUDATA

  ; Copy tiles if needed
  lda vram_copydsthi
  bmi :+
    jsr rf_copy8tiles
    lda #$80
    sta vram_copydsthi
  :

  ; And turn the display on
  ldx #0
  stx PPUSCROLL
  stx PPUSCROLL
  lda #VBLANK_NMI|BG_0000
  sta PPUCTRL
  lda #BG_ON
  ldx ire_emph
  beq :+
    ora #TINT_R|TINT_G|TINT_B
  :
  sta PPUMASK

  lda #helpsect_ire
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:

  lda new_keys+0
  and #KEY_A
  beq not_toggle_emph
    lda ire_emph
    eor #$01
    sta ire_emph
    inc need_reload
  not_toggle_emph:

  lda new_keys+0
  and #KEY_RIGHT|KEY_UP
  beq not_increase
  lda ire_level
  cmp #NUM_IRE_LEVELS - 1
  bcs not_increase
    inc ire_level
    inc need_reload
  not_increase:

  lda new_keys+0
  and #KEY_LEFT|KEY_DOWN
  beq not_decrease
  lda ire_level
  beq not_decrease
    dec ire_level
    inc need_reload
  not_decrease:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop

done:
  rts
.endproc

;;
; Given in A and an emphasis value in X, gets a pointer
; to its IRE value as text in A:Y.
.proc ire_get_msgbase
  lsr a
  lsr a
  lsr a
  ldx ire_emph
  beq :+
    ora #$08
  :
  tax
  clc
  lda ire_msgs2,x
  adc #<ire_msgbase
  tay
  lda #0
  adc #>ire_msgbase
  rts
.endproc

; SMPTE color bars ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.rodata
smpte_layout_ids:
  .byte RF_smpte, RF_cbgray
smpte_helpscreen:
  .byte helpsect_smpte_color_bars, helpsect_color_bars_on_gray

smpte_palettes:
  .byte $0f,$10,$28,$2c, $0f,$14,$16,$02, $0f,$0C,$20,$03, $0f,$1a,$0d,$00
  .byte $0f,$20,$38,$2c, $0f,$14,$16,$12, $0f,$0C,$20,$03, $0f,$2a,$0d,$00

tvSystemkHz: .byte 55, 51, 55

.segment "CODE"

.proc do_smpte
  ldx #0
  bpl do_bars
.endproc

.proc do_601bars
  ldx #1
  ; fall through
.endproc
.proc do_bars
smpte_level = test_state+0
smpte_type  = test_state+1

  lda #0
  sta smpte_level
  stx smpte_type
restart:
  jsr rf_load_tiles

  ldx smpte_type
  lda smpte_layout_ids,x
  jsr rf_load_layout

loop:
  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda smpte_level
  and #$10
  tax
  ldy #16
  :
    lda smpte_palettes,x
    sta PPUDATA
    inx
    dey
    bne :-

  ; And turn the display on
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  ; Update sound
  lda smpte_level
  and #$01
  beq :+
    lda #$88
  :
  sta $4008
  ldx tvSystem
  lda tvSystemkHz,x
  sta $400A
  lda #0
  sta $400B

  ldy smpte_type
  lda smpte_helpscreen,y
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_A
  beq not_increase
    lda #16
    eor smpte_level
    sta smpte_level
  not_increase:

  lda new_keys+0
  and #KEY_SELECT
  beq not_beep
    lda #1
    eor smpte_level
    sta smpte_level
    lda #0
    sta mdfourier_good_phase
  not_beep:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop

done:
  lda #$00   ; Turn off triangle
  sta $4008
  sta $400B
  rts
.endproc

; PLUGE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
pluge_palettes:
  .byte $0F,$0D,$04,$0A
  .byte $0F,$0D,$2D,$2D
pluge_shark_palettes:
  .byte $0F,$10,$02,$1C
  .byte $0F,$00,$0F,$0C
  .byte $10,$20,$32,$3C

.segment "CODE"
.proc do_pluge
palettechoice = test_state+0
emphasis = test_state+1
is_shark = test_state+2
  lda #0
  sta palettechoice
  sta is_shark
  lda #BG_ON
  sta emphasis

restart:
  ; Load initial palette
  lda #$00
  sta PPUMASK
  ldx #$3F
  stx PPUADDR
  ldx #$05
  stx PPUADDR
  sta PPUDATA
  lda #$10
  sta PPUDATA
  asl a
  sta PPUDATA

  jsr rf_load_tiles
  ldx #$02
  ldy #$00
  lda #10
  jsr unpb53_file  ; shark pictogram tiles

  ; Draw PLUGE map on nametable 0
  lda #RF_pluge
  jsr rf_load_layout

  ; Draw shark map on nametable 1
  lda #$00
  tay
  ldx #$24
  jsr ppu_clear_nt
  ldx #$24
  stx PPUADDR
  lda #$00
  sta PPUADDR
  lda #$23  ; starting tile number
  ldy #30
  clc
  sharkrowloop:
    ldx #32
    sharktileloop:
      sta PPUDATA
      adc #4
      and #$2F
      dex
      bne sharktileloop
    adc #1
    and #$23
    dey
    bne sharkrowloop

loop:
  lda #helpsect_pluge
  jsr read_pads_helpcheck
  bcs restart

  lda new_keys+0
  and #KEY_DOWN
  beq not_toggle_emphasis
    lda #$E0
    eor emphasis
    sta emphasis
  not_toggle_emphasis:

  lda new_keys+0
  and #KEY_SELECT
  beq not_toggle_shark
    lda #1
    eor is_shark
    sta is_shark
    lda #0
    sta palettechoice
  not_toggle_shark:

  lda new_keys+0
  and #KEY_A
  beq not_next_palette
    inc palettechoice
    lda #2-1
    ldx is_shark
    beq :+
      lda #3-1
    :
    cmp palettechoice
    bcs not_next_palette
      lda #0
      sta palettechoice
  not_next_palette:

  jsr ppu_wait_vblank

  ; Update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda is_shark
  asl a
  adc palettechoice
  asl a
  asl a
  tax
  ldy #4
  palloadloop:
    lda pluge_palettes,x
    sta PPUDATA
    inx
    dey
    bne palloadloop

  ; And turn the display on
  ; ppu_screen_on doesn't support emphasis
  sty PPUSCROLL
  sty PPUSCROLL
  lda #VBLANK_NMI|BG_0000
  ora is_shark
  sta PPUCTRL
  lda emphasis
  sta PPUMASK

  lda new_keys+0
  and #KEY_B
  bne :+
    jmp loop
  :
  rts
.endproc

; GRADIENT COLOR BARS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"

.proc do_gcbars
  lda #VBLANK_NMI|BG_0000|OBJ_8X16
  sta test_state+0
restart:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette

  ; The first gradient is drawn without grid; instead, the screen
  ; is cleared here.
  ldx #$20
  lda #$00
  tay
  jsr ppu_clear_nt
  lda #RF_gcbars
  jsr rf_load_layout
  lda #RF_gcbars_labels
  jsr rf_load_layout
  lda #RF_gcbars_grid
  jsr rf_load_layout

  ; Set up sprite pattern table
  lda #$FF
  tay
  ldx #$10
  jsr ppu_clear_nt
  ; The "pale" ($3x) colors are drawn as solid color sprites.

sprite_y = $00
sprite_attr = $02
sprite_x = $03
  lda #31
  sta sprite_y
  ldx #0
  stx sprite_attr
  sprboxloop:
    lda #176
    sprcolloop:
      sta sprite_x
      lda sprite_y
      sta OAM+0,x
      clc
      adc #16
      sta OAM+4,x
      lda #$01
      sta OAM+1,x
      sta OAM+5,x
      lda sprite_attr
      sta OAM+2,x
      sta OAM+6,x
      lda sprite_x
      sta OAM+3,x
      sta OAM+7,x
      txa
      clc
      adc #8
      tax
      lda sprite_x
      clc
      adc #8
      cmp #208
      bcc sprcolloop
    inc sprite_attr
    lda sprite_y
    adc #48-1  ; the carry adds an additional 1
    sta sprite_y
    cmp #160
    bcc sprboxloop

  ; And hide the rest of sprites
  jsr ppu_clear_oam

loop:
  jsr ppu_wait_vblank
  lda test_state+0
  jsr ppu_oam_dma_screen_on_xy0

  lda #helpsect_gradient_color_bars
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda new_keys+0
  and #KEY_A
  beq not_toggle_screen
    lda #$01
    eor test_state+0
    sta test_state+0
  not_toggle_screen:

  lda new_keys+0
  and #KEY_B
  beq loop
  rts
.endproc

; GRAY RAMP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.code

.proc do_gray_ramp
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette
  lda #RF_gray_ramp
  jsr rf_load_layout

loop:
  jsr ppu_wait_vblank
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_gray_ramp
  jsr read_pads_helpcheck
  bcs do_gray_ramp
  lda new_keys+0
  and #KEY_B
  beq loop
  rts
.endproc

; COLOR BLEED ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
bleedtile_top:    .byte $00, $55, $55
bleedtile_bottom: .byte $FF, $55, $AA

bleed_palette:
  .byte $0F,$16,$12,$04  ; red and blue
  .byte $0F,$2A,$2C,$04  ; green and cyan
  .byte $0F,$28,$24,$04  ; yellow and magenta
  .byte $0F,$00,$20,$04  ; gray and white
  .byte $0F,$0F,$0F,$20  ; "frame" notice
frame_label:
  .byte "Frame",0

bleed_types:
  .byte RF_bleed, RF_fullstripes
bleed_helpscreen:
  .byte helpsect_color_bleed, helpsect_full_screen_stripes

tvSystemFPS:  .byte 60, 50, 50
.segment "CODE"
;;
; Sets tile 0 to solid color 0 and tile 1 to the color bleed tile
; in colors 2 and 3.
; @param X Pattern select: 0 horizontal; 1 vertical; 2 checkerboard
; @param A invert: $FF or $00
; @param Y Frame counter
.proc prepare_color_bleed_tiles

  ; Draw the frame counter
  pha
  txa
  pha
  jsr clearLineImg
  tya
  jsr bcd8bit
  ora #'0'
  ldx #60
  jsr vwfPutTile
  lda bcd_highdigits
  ora #'0'
  ldx #55
  jsr vwfPutTile
  lda #>frame_label
  ldy #<frame_label
  ldx #24
  jsr vwfPuts
  lda #%00000110  ; Colors 2 and 3
  jsr rf_color_lineImgBuf

  pla
  tax
  pla
  sta $00

  ; Draw the tile in question into
  ; x=0-7 (tile 1 plane 0)
  ; x=4-0
  ldy #0
  l2:
    lda #0
    sta lineImgBuf+16,y
    sta lineImgBuf+17,y

    lda bleedtile_top,x
    eor $00
    sta lineImgBuf+0,y   ; Tile 1 plane 0
    sta lineImgBuf+24,y  ; Tile 2 plane 1
    sta lineImgBuf+32,y  ; Tile 3 plane 0
    eor #$FF
    sta lineImgBuf+40,y  ; Tile 3 plane 1
    iny

    lda bleedtile_bottom,x
    eor $00
    sta lineImgBuf+0,y   ; Tile 1 plane 0
    sta lineImgBuf+24,y  ; Tile 2 plane 1
    sta lineImgBuf+32,y  ; Tile 3 plane 0
    eor #$FF
    sta lineImgBuf+40,y  ; Tile 3 plane 1

    iny
    cpy #8
    bcc l2

  lda #$10
  sta vram_copydstlo
  lda #$00
  sta vram_copydsthi
  rts
.endproc

.proc do_full_stripes
  ldx #1
  bpl do_generic_color_bleed
.endproc

.proc do_color_bleed
  ldx #0
  ; fall through
.endproc
.proc do_generic_color_bleed
tile_shape  = test_state+0
xor_value   = test_state+1
frame_count = test_state+2
bg_type     = test_state+3
  stx bg_type
  ldx #0
  stx tile_shape
  stx xor_value
  stx frame_count

restart:
  jsr ppu_wait_vblank
  lda #$80
  sta PPUCTRL
  sta help_reload
  asl a
  sta PPUMASK

  tay
  lda #$3F
  sta PPUADDR
  sty PPUADDR
  palloop:
    lda bleed_palette,y
    sta PPUDATA
    iny
    cpy #20
    bcc palloop

  lda #0
  sta PPUADDR
  sta PPUADDR
  ldx #16
  blackloop:
    sta PPUDATA
    dex
    bne blackloop

  lda bg_type
  and #$7F
  tax
  lda bleed_types,x
  jsr rf_load_layout

  ; Set up the frame counter sprites
  ldx #0
  ldy #3
  objloop:
    lda #207
    sta OAM+0,x
    tya
    sta OAM+1,x
    asl a
    asl a
    asl a
    sta OAM+3,x
    lda #0
    sta OAM+2,x
    txa
    adc #4
    tax
    iny
    cpy #10
    bcc objloop
  lda #3
  sta OAM+$19
  jsr ppu_clear_oam

  ; Set up the

loop:
  ldx tile_shape
  lda xor_value
  ldy frame_count
  jsr prepare_color_bleed_tiles
  jsr ppu_wait_vblank
  jsr rf_copy8tiles
  ldx #0
  stx OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda bg_type
  asl a  ; bg_type D7 controls sprite on/off
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  jsr ppu_screen_on_xy0

  lda bg_type
  and #$7F
  tay
  lda bleed_helpscreen,y
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  lda das_keys
  and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  sta das_keys
  lda das_timer
  cmp #4
  bcs :+
    lda #1
    sta das_timer
  :
  ldx #0
  jsr autorepeat

  inc frame_count
  lda frame_count
  ldx tvSystem
  cmp tvSystemFPS,x
  bcc :+
    lda #0
    sta frame_count
  :

  lda new_keys+0
  and #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  beq not_flip
    lda #$FF
    eor xor_value
    sta xor_value
  not_flip:

  lda new_keys+0
  and #KEY_SELECT
  beq not_toggle_counter
    lda #$80
    eor bg_type
    sta bg_type
  not_toggle_counter:

  lda new_keys+0
  and #KEY_A
  beq not_switch
    inc tile_shape
    lda tile_shape
    cmp #3
    bcc not_switch
      lda #0
      sta tile_shape
  not_switch:

  lda new_keys
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

; SOLID COLOR SCREEN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.segment "RODATA"

; cur_color=0-2: use one of these
; cur_color=3: use white_color
; cur_color=4: use black_color
solid_color_rgb: .byte $16,$1A,$12

color_msg:  .byte "Color:",0

.segment "CODE"

.proc do_solid_color
cur_color = test_state+0
color_box_open = test_state+1
white_color = test_state+2
black_color = test_state+3
is_windowed = test_state+4
cur_bg_color = lineImgBuf+128
text_dark_color = lineImgBuf+129
text_light_color = lineImgBuf+130

  lda #3
  sta cur_color
  lda #0
  sta color_box_open
  sta is_windowed
  lda #$20
  sta white_color
  lda #$0F
  sta black_color
restart:
  jsr rf_load_tiles
  lda #RF_solid
  jsr rf_load_layout

loop:
  ; Prepare color display
  jsr clearLineImg
  lda white_color
  lsr a
  lsr a
  lsr a
  lsr a
  ldx #44
  jsr vwfPutNibble
  lda white_color
  and #$0F
  ldx #50
  jsr vwfPutNibble
  ldy #<color_msg
  lda #>color_msg
  ldx #8
  jsr vwfPuts

  lda #%1001
  jsr rf_color_lineImgBuf
  lda #$02
  sta vram_copydsthi
  lda #$00
  sta vram_copydstlo

  ; Choose palette display
  ; 0-2: RGB, no box
  ; 3: white, optional box
  ; 4: black, no box
  ldx cur_color
  cpx #3
  beq load_palette_white
  bcs load_palette_black
  lda solid_color_rgb,x
  bcc have_bg_color_no_text
load_palette_white:
  lda white_color
  ldx color_box_open
  beq have_bg_color_no_text
  ldx #$02
  stx text_dark_color
  ldx #$38
  stx text_light_color
  bne have_bg_color
load_palette_black:
  lda black_color
have_bg_color_no_text:
  ldx is_windowed
  bne :+
    tax
  :
  stx text_dark_color
  stx text_light_color
have_bg_color:
  sta cur_bg_color

  jsr ppu_wait_vblank
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda is_windowed
  bne :+
    lda cur_bg_color
  :
  sta PPUDATA
  lda cur_bg_color
  sta PPUDATA
  lda text_dark_color
  sta PPUDATA
  lda text_light_color
  sta PPUDATA
  jsr rf_copy8tiles
  lda #VBLANK_NMI|BG_0000
  clc
  jsr ppu_screen_on_xy0

  lda #helpsect_solid_color_screen
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:

  lda new_keys+0
  and #KEY_RIGHT
  beq not_right
  lda color_box_open
  beq next_color
    lda white_color
    and #$0F
    clc
    adc #1
    cmp #$0D
    bcc :+
      lda #$00
    :
    eor white_color
    and #$0F
    eor white_color
    sta white_color
    jmp not_right
  next_color:
    inc cur_color
    lda cur_color
    cmp #5
    bcc not_right
      lda #0
      sta cur_color
  not_right:

  lda new_keys+0
  and #KEY_LEFT
  beq not_left
  lda color_box_open
  beq prev_color
    lda white_color
    and #$0F
    clc
    adc #<-1
    bpl :+
      lda #$0C
    :
    eor white_color
    and #$0F
    eor white_color
    sta white_color
    jmp not_left
  prev_color:
    dec cur_color
    bpl not_left
      lda #4
      sta cur_color
  not_left:

  lda new_keys+0
  and #KEY_UP
  beq not_up
  lda color_box_open
  beq not_up
    lda white_color
    clc
    adc #16
    cmp #$40
    bcc :+
      lda #$30
    :
    sta white_color
  not_up:

  lda new_keys+0
  and #KEY_DOWN
  beq not_down
  lda color_box_open
  beq not_down
    lda white_color
    sec
    sbc #16
    bcs :+
      lda #$00
    :
    sta white_color
  not_down:

  lda new_keys+0
  and #KEY_SELECT
  beq not_select
    lda #$0F
    eor is_windowed
    sta is_windowed
  not_select:

  lda new_keys+0
  bpl notA
  lda cur_color
  cmp #3
  bcc notA
  bne A_toggle_black
    lda #$01
    eor color_box_open
    sta color_box_open
    bcs notA
  A_toggle_black:
    lda #$0D ^ $0F
    eor black_color
    sta black_color
  notA:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

.proc vwfPutNibble
  cmp #10
  bcc :+
    adc #'A'-'9'-2
  :
  adc #'0'
  jmp vwfPutTile
.endproc

; CONVERGENCE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc do_convergence
gridlinestype = test_state+0
gridinvert = test_state+1  ; 0F or 20
colorsborder = test_state+2  ; 00 or 0F
cur_side = test_state+3
  lda #0
  sta colorsborder
  sta gridlinestype
  sta cur_side
  lda #$0F
  sta gridinvert
restart:
  lda #VBLANK_NMI
  ldy #0
  sta help_reload
  sta PPUCTRL
  sty PPUMASK

  ; First nametable: Gridlines
  lda #4
  ldx #$20
  jsr ppu_clear_nt
  ; address is now $2400

rowsleft = $00
blocksleft = $01
  ldy #30
  rside_rowloop:
    tya
    and #$03
    cmp #$03
    beq :+
      lda #0
    :
    and #2
    ldx #8
    rside_tileloop:
      sta PPUDATA
      sta PPUDATA
      sta PPUDATA
      eor #1
      sta PPUDATA
      eor #1
      dex
      bne rside_tileloop
    dey
    bne rside_rowloop
  ldy #8
  lda #$00
  rside_attrrowloop:
    ldx #8
    rside_attrtileloop:
      sta PPUDATA
      eor #$55
      dex
      bne rside_attrtileloop
    eor #$AA
    dey
    bne rside_attrrowloop

  ; Load pattern table to $0000 (both X and Y are 0 at this point)
  lda #11
  jsr unpb53_file

loop:
  lda #helpsect_convergence
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:

  lda new_keys+0
  and #KEY_SELECT
  beq not_invert_grays
    lda #$2F
    eor gridinvert
    sta gridinvert
  not_invert_grays:

  lda new_keys+0
  bpl not_invert_side
    lda #1
    eor cur_side
    sta cur_side
  not_invert_side:

  lda new_keys+0
  and #KEY_UP|KEY_DOWN
  beq not_updown
  ldy cur_side
  beq updown_lside
    lda #$0F
    eor colorsborder
    sta colorsborder
    jmp not_updown
  updown_lside:
    cmp #KEY_UP
    lda #1
    adc gridlinestype
    cmp #3
    bcc :+
      sbc #3
    :
    sta gridlinestype
  is_down:


  not_updown:

  jsr ppu_wait_vblank
  lda #$3F
  ldx #$00
  sta PPUADDR
  stx PPUADDR
  lda cur_side
  lsr a
  bcc load_palette_lside
    ; right side
    ldx #3
    ldy colorsborder
    rpalloop:
      lda #$0F
      sta PPUDATA
      sta PPUDATA
      tya
      ora convergence_rside_palette,x
      sta PPUDATA
      lda convergence_rside_palette,x
      sta PPUDATA
      dex
      bpl rpalloop
    bmi load_palette_done
  load_palette_lside:
    ldx gridlinestype
    lda gridinvert
    lpalloop1:
      sta PPUDATA
      dex
      bpl lpalloop1
    ldx #3
    eor #$2F
    lpalloop2:
      sta PPUDATA
      dex
      bpl lpalloop2
  load_palette_done:
  lda cur_side
  ora #VBLANK_NMI
  clc
  jsr ppu_screen_on_xy0

  lda new_keys
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

.rodata
convergence_rside_palette:
  .byte $16, $2A, $12, $20
