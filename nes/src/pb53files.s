;
; List of compressed graphics files for 240p test suite
; Copyright 2016 Damian Yerrick
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

; In July 2016, most compressed data was moved into this file.
; This allows storing compressed data in a bank other than
; the main program bank, even on a 32K mapper like BNROM.

.export sb53_files, unpb53_files, iu53_files
.exportzp IU53_BANK

.segment "PB53TABLES"
unpb53_files:
  .addr stopwatch_balls
  .byte <.BANK(stopwatch_balls), 62
  .addr fizzter_digits
  .byte <.BANK(fizzter_digits), 64
  .addr stdtiles_pb53
  .byte <.BANK(stdtiles_pb53), 32
  .addr kikitiles_pb53
  .byte <.BANK(kikitiles_pb53), 24
  .addr backlight_sprites
  .byte <.BANK(backlight_sprites), 4
  .addr gus_sprite
  .byte <.BANK(gus_sprite), 48
  .addr help_cursor_pb53
  .byte <.BANK(help_cursor_pb53), 2
  .addr overclock_s0_pb53
  .byte <.BANK(overclock_s0_pb53), 2
  .addr megatontiles_pb53
  .byte <.BANK(megatontiles_pb53), 20
  .addr overscan_pb53
  .byte <.BANK(overscan_pb53), 18

  .addr pluge_shark_pb53
  .byte <.BANK(pluge_shark_pb53), 16
  .addr convergence_pb53
  .byte <.BANK(convergence_pb53), 5
  .addr serialanalyzer_pb53
  .byte <.BANK(serialanalyzer_pb53), 5

;
; 7654 3210
; || | ++--- Destination nametable
; +|-+------ Destination pattern table (0: $0000, 1: $1000, 8: both)
;  +-------- Number of nametables (0: one; 1: two)

SB53_MAP_2000 = $00
SB53_MAP_2400 = $04
SB53_MAP_WIDE = $40
SB53_PAT_0000 = $00
SB53_PAT_1000 = $10
SB53_PAT_BOTH = $80

sb53_files:
  .addr gus_bg_sb53
  .byte <.BANK(gus_bg_sb53), SB53_PAT_0000|SB53_MAP_2000
  .addr greenhillzone_sb53
  .byte <.BANK(greenhillzone_sb53), SB53_PAT_0000|SB53_MAP_WIDE

iu53_files:
  .addr monoscope_ntsc_iu53
  .addr monoscope_pal_iu53
  .addr sharpness_iu53
  .addr stopwatchface_iu53
  .addr gus_portrait_iu53

.segment "BANK00"
gus_bg_sb53:         .incbin "obj/nes/gus_bg.sb53"
greenhillzone_sb53:  .incbin "obj/nes/greenhillzone.sb53"

IU53_BANK = <.bank(*)
monoscope_ntsc_iu53: .incbin "obj/nes/monoscope60.iu53"
monoscope_pal_iu53:  .incbin "obj/nes/monoscope50.iu53"
sharpness_iu53:      .incbin "obj/nes/sharpness.iu53"
stopwatchface_iu53:  .incbin "obj/nes/stopwatchface.iu53"
gus_portrait_iu53:   .incbin "obj/nes/gus_portrait.iu53"

stopwatch_balls:     .incbin "obj/nes/stopwatchhand.chr.pb53",2
fizzter_digits:      .incbin "obj/nes/fizzter_digits.chr.pb53",2
kikitiles_pb53:      .incbin "obj/nes/kikitiles16.chr.pb53",2
gus_sprite:          .incbin "obj/nes/gus_sprite.chr.pb53",2
megatontiles_pb53:   .incbin "obj/nes/megatontiles.chr.pb53",2
pluge_shark_pb53:    .incbin "obj/nes/pluge_shark_4color.chr.pb53",2
overscan_pb53:       .incbin "obj/nes/overscan.chr.pb53",2
backlight_sprites:   .incbin "obj/nes/backlight_sprites.chr.pb53",2
stdtiles_pb53:       .incbin "obj/nes/stdtiles.chr.pb53",2
convergence_pb53:    .incbin "obj/nes/convergence.chr.pb53",2
serialanalyzer_pb53: .incbin "obj/nes/serialanalyzer.chr.pb53",2

help_cursor_pb53:
  .byte $87  ; blank tile
  .byte $40,$FF,$9F,$87,$81,$87,$9F,$FF,$82  ; arrow tile
overclock_s0_pb53:
  .byte $84
  .byte %00111111,$FF,$00,$80

.segment "BANK01"

; Overflow pb53/sb53 files can go in bank 1, but the only ones left
; are gatedata (Shadow sprite tiles and Kiki map).
