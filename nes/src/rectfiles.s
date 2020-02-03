.include "rectfill.inc"
.export rectfill_layouts

.macro rectfile name, address, nametable, tileno
  .assert (* - rectfill_layouts) / 4 < 256, error, "too many rectfiles"
  name = <((* - rectfill_layouts) / 4)
  .exportzp name
  .addr address
  .byte nametable
  .ifnblank tileno
    .byte tileno
  .else
    .byte $ff
  .endif
.endmacro

.segment "GATEDATA"

; each record is 4 bytes, consisting of
; address, nametable ($20 or $24), label starting tile
rectfill_layouts:
  rectfile RF_ire, ire_rects, $20
  rectfile RF_smpte, smpte_rects, $20
  rectfile RF_cbgray, cbgray_rects, $20
  rectfile RF_pluge, pluge_rects, $20
  rectfile RF_gcbars, gcbars_nogrid, $20
  rectfile RF_gcbars_labels, gcbars_labels, $20, $20
  rectfile RF_gcbars_grid, gcbars_grid, $24
  rectfile RF_cpsgrid_224, cpsgrid_224p_rects, $20
  rectfile RF_cpsgrid_240, cpsgrid_240p_rects, $24
  rectfile RF_gray_ramp, gray_ramp_rects, $20

  rectfile RF_bleed, bleed_rects, $20
  rectfile RF_fullstripes, fullstripes_rects, $20
  rectfile RF_solid, solid_color_rects, $20
  rectfile RF_sw_hmsf, stopwatch_labels, $20, $70
  rectfile RF_audiosync, audiosync_rects, $20
  rectfile RF_megaton, megaton_rects, $20, $18
  rectfile RF_megaton_end, megaton_result_rects, $20, $18
  rectfile RF_overscan, overscan_rects, $20, $80
  rectfile RF_overclock, overclock_rects, $20, $02
  rectfile RF_zapper, zapper_rects, $20, $20

  rectfile RF_crowd, crowd_labels, $20, $20
  rectfile RF_mdfourier, mdfourier_labels, $20, $20
  rectfile RF_mdfourier_15k, mdfourier_15k_rects, $2C

ire_rects:
  rf_rect   0,  0,256,240,$00, 0  ; Clear screen to black
  rf_rect  64, 64,192,176,$0C, 0  ; Color 3: inside
  rf_rect 160,192,224,200,$F8, RF_INCR  ; text area
  .byte $00
  rf_attr  0,  0,256, 240, 0
  .byte $00
  .byte $00

smpte_rects:
  rf_rect   0,  0, 32,160,$04, 0  ; bar 1
  rf_rect  32,  0, 40,160,$10, 0  ; bar 1-2
  rf_rect  40,  0, 72,160,$08, 0  ; bar 2 (allegedly not so yellow)
  rf_rect  72,  0, 80,160,$11, 0  ; bar 2-3
  rf_rect  80,  0,112,160,$0c, 0  ; bar 3
  rf_rect 112,  0,144,160,$04, 0  ; bar 4
  rf_rect 144,  0,176,160,$04, 0  ; bar 5
  rf_rect 176,  0,184,160,$10, 0  ; bar 5-6
  rf_rect 184,  0,216,160,$08, 0  ; bar 6
  rf_rect 216,  0,224,160,$11, 0  ; bar 6-7
  rf_rect 224,  0,256,160,$0c, 0  ; bar 7
  rf_rect   0,160,256,240,$00, 0  ; black
  rf_rect   0,160, 32,176,$0c, 0  ; bar 7
  rf_rect  32,160, 40,176,$18, 0  ; bar 7-
  rf_rect  72,160, 80,176,$19, 0  ; bar -5
  rf_rect  80,160,112,176,$04, 0  ; bar 5
  rf_rect 144,160,176,176,$0c, 0  ; bar 3
  rf_rect 176,160,184,176,$18, 0  ; bar 3-
  rf_rect 216,160,224,176,$19, 0  ; bar -1
  rf_rect 224,160,256,176,$04, 0  ; bar 1
  rf_rect   0,176, 48,240,$04, 0  ; i
  rf_rect  48,176, 96,240,$08, 0  ; white
  rf_rect  96,176,144,240,$0C, 0  ; q
  rf_rect 184,176,200,240,$08, 0  ; 0d
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr 112,  0,144,160, 3  ; green bar
  rf_attr 144,  0,256,160, 1  ; bars 5-7
  rf_attr   0,160,112,176, 1  ; bars 7-5
  rf_attr   0,176,144,240, 2  ; i, y, q
  rf_attr 160,176,256,240, 3  ; 0d
  .byte $00

cbgray_rects:
  rf_rect   0,  0,256,240,$04, 0  ; bar 1 and bg

  rf_rect  32, 48, 40, 96,$10, 0  ; bar 1-2
  rf_rect  40, 48, 72, 96,$08, 0  ; bar 2 (allegedly not so yellow)
  rf_rect  72, 48, 80, 96,$11, 0  ; bar 2-3
  rf_rect  80, 48,112, 96,$0c, 0  ; bar 3
  rf_rect 112, 48,144, 96,$04, 0  ; bar 4
  rf_rect 144, 48,176, 96,$04, 0  ; bar 5
  rf_rect 176, 48,184, 96,$10, 0  ; bar 5-6
  rf_rect 184, 48,216, 96,$08, 0  ; bar 6
  rf_rect 216, 48,224, 96,$11, 0  ; bar 6-7
  rf_rect 224, 48,256, 96,$0c, 0  ; bar 7
  rf_rect   0,144, 32,192,$0c, 0  ; bar 7
  rf_rect  32,144, 40,192,$12, 0  ; bar 7-6
  rf_rect  40,144, 72,192,$08, 0  ; bar 6
  rf_rect  72,144, 80,192,$13, 0  ; bar 6-5
  rf_rect  80,144,112,192,$04, 0  ; bar 5
  rf_rect 112,144,144,192,$04, 0  ; bar 4
  rf_rect 144,144,176,192,$0c, 0  ; bar 3
  rf_rect 176,144,184,192,$12, 0  ; bar 3-2
  rf_rect 184,144,216,192,$08, 0  ; bar 2
  rf_rect 216,144,224,192,$13, 0  ; bar 2-1
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr 112, 48,144, 96, 3  ; green bar
  rf_attr 144, 48,256, 96, 1  ; bars 5-7
  rf_attr   0,144,112,192, 1  ; bars 7-5
  rf_attr 112,144,144,192, 3  ; green bar
  .byte $00
  .byte $00  ; no labels

pluge_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect  16, 48, 32,192,$0A, 0  ; lowest color above black
  rf_rect 224, 48,240,192,$0A, 0
  rf_rect  48, 48, 64,192,$04, 0  ; below black
  rf_rect 192, 48,208,192,$04, 0
  rf_rect  80, 48,176, 96,$0C, 0  ; gray boxes in center
  rf_rect  80, 96,176,144,$08, 0
  rf_rect  80,144,176,192,$04, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  80, 48,176,192, 1
  .byte $00
  .byte $00  ; no labels

gcbars_grid:
  rf_rect   0,  0,256,240,$16, RF_ROWXOR|RF_COLXOR
gcbars_nogrid:
  rf_rect  80, 32,112, 64,$04, 0  ; red 0
  rf_rect 112, 32,144, 64,$08, 0  ; red 1
  rf_rect 144, 32,176, 64,$0C, 0  ; red 2
  rf_rect  80, 80,112,112,$04, 0  ; green 0
  rf_rect 112, 80,144,112,$08, 0  ; green 1
  rf_rect 144, 80,176,112,$0C, 0  ; green 2
  rf_rect  80,128,112,160,$04, 0  ; blue 0
  rf_rect 112,128,144,160,$08, 0  ; blue 1
  rf_rect 144,128,176,160,$0C, 0  ; blue 2
  rf_rect  80,176,112,208,$04, 0  ; white 0
  rf_rect 112,176,144,208,$08, 0  ; white 1
  rf_rect 144,176,208,208,$0C, 0  ; white 2-3
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  80, 32,176, 64, 1  ; red
  rf_attr  80, 80,176,112, 2  ; green
  rf_attr  80,128,176,160, 3  ; blue
  .byte $00
  ; Labels are a separate file.  This $00 is both the "no labels"
  ; sign for gcbars_grid and the "no rects" sign for gcbars_labels
gcbars_labels:
  .byte $00
  rf_label  80, 24, 3, 0
  .byte "0",0
  rf_label 112, 24, 3, 0
  .byte "1",0
  rf_label 144, 24, 3, 0
  .byte "2",0
  rf_label 176, 24, 3, 0
  .byte "3",0
  rf_label  48, 40, 3, 0
  .byte "Red",0
  rf_label  48, 88, 3, 0
  .byte "Green",0
  rf_label  48,136, 3, 0
  .byte "Blue",0
  rf_label  48,184, 3, 0
  .byte "White",0
  .byte $00

cpsgrid_224p_rects:
  rf_rect   0,  0,256,224,$16, RF_ROWXOR|RF_COLXOR
  rf_rect   0,224,256,240,$00, 0
  .byte $00
  rf_attr   0,  0,256,240, 1
  rf_attr  16, 16,240,208, 0
  .byte $00, $00
cpsgrid_240p_rects:
  rf_rect   0,  0,256,240,$16, RF_ROWXOR|RF_COLXOR
  .byte $00
  rf_attr   0,  0,256,240, 1
  rf_attr  16, 16,240,224, 0
  .byte $00, $00

gray_ramp_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect  32, 24, 48,120,$01, 0
  rf_rect  48, 24, 64,120,$02, 0
  rf_rect  64, 24, 80,120,$03, 0
  rf_rect  80, 24, 96,120,$04, 0
  rf_rect  96, 24,112,120,$05, 0
  rf_rect 112, 24,128,120,$06, 0
  rf_rect 128, 24,144,120,$07, 0
  rf_rect 144, 24,160,120,$08, 0
  rf_rect 160, 24,176,120,$09, 0
  rf_rect 176, 24,192,120,$0a, 0
  rf_rect 192, 24,208,120,$0b, 0
  rf_rect 208, 24,224,120,$0c, 0
  rf_rect  32,120, 48,216,$0c, 0
  rf_rect  48,120, 64,216,$0b, 0
  rf_rect  64,120, 80,216,$0a, 0
  rf_rect  80,120, 96,216,$09, 0
  rf_rect  96,120,112,216,$08, 0
  rf_rect 112,120,128,216,$07, 0
  rf_rect 128,120,144,216,$06, 0
  rf_rect 144,120,160,216,$05, 0
  rf_rect 160,120,176,216,$04, 0
  rf_rect 176,120,192,216,$03, 0
  rf_rect 192,120,208,216,$02, 0
  rf_rect 208,120,224,216,$01, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00,$00

bleed_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect  16, 32,240, 64,$01, 0
  rf_rect  16, 80,240,112,$01, 0
  rf_rect  16,128,240,160,$01, 0
  rf_rect  16,176,240,208,$01, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  16, 32,240, 64, 1
  rf_attr  16, 80,240,112, 2
  rf_attr  16,128,240,160, 3
  .byte $00,$00
fullstripes_rects:
  rf_rect   0,  0,256,240,$01, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00,$00

solid_color_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect 160, 32,224, 40,$20, RF_INCR
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00,$00

stopwatch_labels:
  .byte 0
  rf_label  56, 40, 2, 0
  .byte "hours",0
  rf_label  96, 40, 2, 0
  .byte "minutes",0
  rf_label 136, 40, 2, 0
  .byte "seconds",0
  rf_label 176, 40, 2, 0
  .byte "frames",0
  .byte 0

audiosync_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect   0,192,256,200,$04, 0
  rf_rect   0, 80,256, 96,$0C, 0
  rf_rect  32, 80,224, 96,$04, 0
  rf_rect  56, 80,200, 96,$08, 0
  rf_rect  80, 80,176, 96,$0C, 0
  rf_rect 104, 80,152, 96,$00, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr  32, 80,224,112, 1
  .byte $00,$00

megaton_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect 112, 96,144,128,$04, RF_INCR  ; The receptor
  rf_rect  96,136,160,144,$80, RF_INCR  ; Raw lag
  rf_rect  40, 48, 40 + 8 * 2, 48 + 8 * 10, $88, RF_INCR  ; Lag history
  .byte 0
  rf_attr   0,  0,256,240, 0
  .byte 0
  ; Followed by labels
  ; a later refactor may require these to be first in order to
  ; arrange for "off" and "on" to be allocated at fixed tile indices
  rf_label 116,200, 3, 0
  .byte "on",0
  rf_label 116,208, 3, 0
  .byte "on",0
  rf_label  32,184, 3, 0
  .byte "Press A when reticles align",0
  rf_label  48,192, 3, 0
  .byte "Direction",0
  rf_label 116,192, 3, 0
  .byte "horizontal",0
  rf_label 180,192, 3, 0
  .byte "vertical",0
  rf_label  48,200, 3, 0
  .byte "Randomize",0
  rf_label  48,208, 3, 0
  .byte "Audio",0
  .byte 0

megaton_result_rects:
  rf_rect   0,184,256,240,$00, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte 0
  ; rf_label stuff goes here
  rf_label  32,40, 3, 0
  .byte "Measured lag:",0
  rf_label  32,56 + 8 * 10, 3, 0
  .byte "Average:",0
  rf_label  32,184, 3, 0
  .byte "Press B to close",0
  .byte 0

overscan_rects:
  rf_rect   0,  0,256,240,$00, 0        ; Clear screen
  rf_rect 112, 40,128, 48,$F0, RF_INCR  ; Top pixels: $F0-$F1
  rf_rect 120, 48,136, 56,$F8, RF_INCR  ; Top percentage: $F8-$F9
  rf_rect 112,184,128,192,$F2, RF_INCR  ; Bottom pixels: $F2-$F3
  rf_rect 128,184,144,192,$80, RF_INCR  ; [Bottom] px
  rf_rect 120,192,136,200,$FA, RF_INCR  ; Bottom percentage: $FA-$FB
  rf_rect  40,112, 56,120,$F4, RF_INCR  ; Left pixels: $F4-$F5
  rf_rect  40,120, 56,128,$80, RF_INCR  ; [Left] px
  rf_rect  40,128, 56,136,$FC, RF_INCR  ; Left percentage: $FC-$FD
  rf_rect 200,112,216,120,$F6, RF_INCR  ; Right pixels: $F6-$F7
  rf_rect 200,120,216,128,$80, RF_INCR  ; [Right] px
  rf_rect 200,128,216,136,$FE, RF_INCR  ; Right percentage: $FE-$FF
  .byte 0

  rf_attr   0,  0,256,240, 0
  .byte 0

  ; These start at $80 and are replicated using rects above
  rf_label 131,40, 3, 2
  .byte "px",0   ; $80-$81
  .byte 0

overclock_rects:
  rf_rect   0,  0,256,240,$00, 0
  rf_rect 128,104,192,152,$80, RF_INCR  ; text area
  .byte 0

  rf_attr   0,  0,256,240, 0
  .byte 0

  rf_label  64,104, 2, 0
  .byte "Cycles/line:",0
  rf_label  64,112, 2, 0
  .byte "Lines/frame:",0
  rf_label  64,120, 2, 0
  .byte "NMI scanline:",0
  rf_label  64,128, 2, 0
  .byte "TV system:",0
  rf_label  64,136, 2, 0
  .byte "Frame rate:",0
  rf_label  64,144, 2, 0
  .byte "CPU speed:",0
  .byte 0

zapper_rects:
  rf_rect   0,  0,256,240,$04, 0  ; Letterbox (incl. sprite 0 trigger)
  rf_rect   0, 24,256,216,$00, 0  ; Blank center
  rf_rect  64,184,80,200,$F8, RF_INCR  ; text area (Y, height)
  .byte $00
zapper_attrs:
  rf_attr  0,  0,256, 240, 0
  .byte $00
zapper_texts:
  rf_label 16, 168, 1, 0
  .byte "Zapper test",0
  rf_label 16, 184, 1, 0
  .byte "Light Y:",0
  rf_label 16, 192, 1, 0
  .byte "Height:",0
  rf_label 16, 208, 1, 0
  .byte "B: Exit",0
  .byte $00

crowd_labels:
  rf_rect   0,  0,256,240,$00, 0  ; blank the screen
  .byte $00
  rf_attr  0,  0,256, 240, 0
  .byte $00
  rf_label  80, 96, 3, 0
  .byte 34,"Crowd",34," by Kragen",0
  rf_label  80,112, 3, 0
  .byte "Ported to NES",0
  rf_label  80,120, 3, 0
  .byte "by rainwarrior",0
  rf_label  80,144, 3, 0
  .byte "Reset: exit",0
  .byte $00

mdfourier_labels:
  rf_rect   0,  0,256,240,$00, 0  ; blank the screen
  .byte $00
  rf_attr   0,  0,256,240, 0
  rf_attr   0,160,256,192, 1  ; make the "phase is trash" message red
  .byte $00

  ; Overprint two messages to allocate space for both in CHR RAM.
  rf_label  80,160, 3, 0
  .byte "OK", 0
  rf_label  80,160, 3, 0
  .byte "Trash. Results may be wrong.",0
  rf_label  80,168, 3, 0
  .byte "Hold Start and press Reset.",0

  rf_label  80, 80, 3, 0
  .byte "MDFourier v7",0
  rf_label  80, 96, 2, 0
  .byte "tone generator",0
  rf_label  80,120, 3, 0
  .byte "A: Start   B: Stop",0
  rf_label  80,128, 2, 0
  .byte $86,$87,": Change background",0

  rf_label  80,152, 2, 0
  .byte "Triangle phase:",0
  .byte $00

mdfourier_15k_rects:
  rf_rect   0,  0,256,240,$04, 0
  rf_rect  40,  0,216,240,$08, 0
  rf_rect  80,  0,176,240,$0C, 0
  .byte $00
  rf_attr   0,  0,256,240, 0
  .byte $00
  .byte $00  ; no labels

