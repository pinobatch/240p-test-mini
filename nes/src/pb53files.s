.export sb53_files, unpb53_files

.segment "PB53TABLES"
unpb53_files:
  .addr stopwatch_balls
  .byte <.BANK(stopwatch_balls), 96
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
  .byte <.BANK(megatontiles_pb53), 24
  .addr overscan_pb53
  .byte <.BANK(overscan_pb53), 40

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
  .addr linearity_ntsc
  .byte <.BANK(linearity_ntsc), SB53_PAT_0000|SB53_MAP_2000
  .addr linearity_pal
  .byte <.BANK(linearity_pal), SB53_PAT_0000|SB53_MAP_2000
  .addr linearity_grid_ntsc
  .byte <.BANK(linearity_grid_ntsc), SB53_PAT_1000|SB53_MAP_2400
  .addr linearity_grid_pal
  .byte <.BANK(linearity_grid_pal), SB53_PAT_1000|SB53_MAP_2400
  .addr sharpnessgray_sb53
  .byte <.BANK(sharpnessgray_sb53), SB53_PAT_0000|SB53_MAP_2000
  .addr gus_portrait_sb53
  .byte <.BANK(gus_portrait_sb53), SB53_PAT_0000|SB53_MAP_2000
  .addr lag_clock_face_sb53
  .byte <.BANK(lag_clock_face_sb53), SB53_PAT_0000|SB53_MAP_2000
  .addr crosstalk_sb53
  .byte <.BANK(crosstalk_sb53), SB53_PAT_0000|SB53_MAP_2000

.segment "BANK00"
gus_bg_sb53:         .incbin "obj/nes/gus_bg.sb53"
gus_sprite:          .incbin "obj/nes/gus_sprite.chr.pb53",2
help_cursor_pb53:
  .byte $87  ; blank tile
  .byte $40,$FF,$9F,$87,$81,$87,$9F,$FF,$82  ; arrow tile

linearity_ntsc:      .incbin "obj/nes/linearity_ntscgray.sb53"
linearity_pal:       .incbin "obj/nes/linearity_palgray.sb53"
linearity_grid_ntsc: .incbin "obj/nes/linearity_grid_ntscgray.sb53"
linearity_grid_pal:  .incbin "obj/nes/linearity_grid_palgray.sb53"

gus_portrait_sb53:   .incbin "obj/nes/gus_portrait.sb53"
greenhillzone_sb53:  .incbin "obj/nes/greenhillzone.sb53"
kikitiles_pb53:      .incbin "obj/nes/kikitiles16.chr.pb53",2
overscan_pb53:
  .incbin "obj/nes/overscan.chr.pb53",2
backlight_sprites:   .incbin "obj/nes/backlight_sprites.chr.pb53",2
overclock_s0_pb53:
  .byte $84
  .byte %00111111,$FF,$00,$80

.segment "BANK01"
sharpnessgray_sb53:  .incbin "obj/nes/sharpnessgray.sb53"
crosstalk_sb53:      .incbin "obj/nes/crosstalk.sb53"
stopwatch_balls:     .incbin "obj/nes/lag_clock_balls.chr.pb53",2
lag_clock_face_sb53: .incbin "obj/nes/lag_clock_face.sb53"
fizzter_digits:      .incbin "obj/nes/fizzter_digits.chr.pb53",2
stdtiles_pb53:       .incbin "obj/nes/stdtiles.chr.pb53",2
megatontiles_pb53:   .incbin "obj/nes/megatontiles.chr.pb53",2

