;
; Sound test for 240p test suite
; Copyright 2018 Damian Yerrick
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
include "src/gb.inc"
include "src/global.inc"

section "soundtest",ROM0,align[4]
; "".join("%x" % round(sin(x*pi/32) * 7.5 + 7.5) for x in range(1, 64, 2))

waveram_sinx:
  db $8a,$bc,$de,$ff,$ff,$ed,$cb,$a8,$75,$43,$21,$00,$00,$12,$34,$57
waveram_sin2x:
  db $9c,$ef,$fe,$c9,$63,$10,$01,$36,$9c,$ef,$fe,$c9,$63,$10,$01,$36
waveram_sin4x:
  db $bf,$fb,$40,$04,$bf,$fb,$40,$04,$bf,$fb,$40,$04,$bf,$fb,$40,$04
waveram_sin8x:
  db $cc,$33,$cc,$33,$cc,$33,$cc,$33,$cc,$33,$cc,$33,$cc,$33,$cc,$33
waveram_sin16x:
  db $c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3

activity_soundtest::
  ld a,$80
  ldh [rNR52],a  ; Bring audio circuit out of reset
  ld a,$FF
  ldh [rNR51],a  ; Set panning
  ld a,$77
  ldh [rNR50],a  ; Set master volume
  xor a
  ldh [rNR10],a  ; Disable pulse 1 sweep

  ld a,PADF_A|PADF_B|PADF_START|PADF_DOWN|PADF_UP|PADF_LEFT|PADF_RIGHT
  ld b,helpsect_sound_test_frequency
  call helpscreen

  ; Look for control keys
  ld hl,new_keys
  bit PADB_B,[hl]
  jr z,.not_exit
    xor a
    ld [rNR52],a
    ret
  .not_exit:

  bit PADB_START,[hl]
  jr z,.not_help
    ; Save menu selection, show help, and restore menu selection
    ld a,[help_wanted_page]
    ld c,a
    ld a,[help_cursor_y]
    ld b,a
    push bc

    ld a,PADF_A|PADF_B|PADF_START|PADF_LEFT|PADF_RIGHT
    ld b,helpsect_sound_test
    call helpscreen

    pop bc
    ld a,b
    ld [help_cursor_y],a
    ld a,c
    ld [help_wanted_page],a
    jr activity_soundtest
  .not_help:

  ld a,[help_cursor_y]
  ld de,soundtest_handlers
  call de_index_a
  call jp_hl
  jr activity_soundtest

soundtest_handlers:
  dw soundtest_8k, soundtest_4k, soundtest_2k, soundtest_1k
  dw soundtest_500, soundtest_250, soundtest_125, soundtest_62
  dw soundtest_1kleft, soundtest_1kright, soundtest_1kpulse
  dw soundtest_hiss, soundtest_buzz

soundtest_8k:
  ld hl,waveram_sin16x
  jr soundtest_hl_wave

soundtest_4k:
  ld hl,waveram_sin8x
  jr soundtest_hl_wave

soundtest_2k:
  ld hl,waveram_sin4x
  jr soundtest_hl_wave

soundtest_1kright:
  ld a,$0F
  ldh [rNR51],a  ; Set panning
  jr soundtest_1k

soundtest_1kleft:
  ld a,$F0
  ldh [rNR51],a  ; Set panning
soundtest_1k:
  ld hl,waveram_sin2x
soundtest_hl_wave:
  ld de,2048-131
  jr soundtest_de_hl

soundtest_500:
  ld de,2048-131
  jr soundtest_de_period

soundtest_250:
  ld de,2048-262
  jr soundtest_de_period

soundtest_125:
  ld de,2048-524
  jr soundtest_de_period

soundtest_62:
  ld de,2048-1048
soundtest_de_period:
  ld hl,waveram_sinx

;;
; @param de wave frequency
; @param hl pointer to wave ram data
soundtest_de_hl:
  xor a
  ldh [rNR30],a  ; unlock waveram
  ld c,low(_AUD3WAVERAM)
  ld b,16
  .waveloop:
    ld a,[hl+]
    ld [$FF00+c],a
    inc c
    dec b
    jr nz,.waveloop

  ld a,$80
  ldh [rNR30],a  ; lock waveram
  ld a,$20
  ldh [rNR32],a  ; 100% volume
  ld a,e
  ldh [rNR33],a  ; period lo
  ld a,d
  or $80
  ldh [rNR34],a  ; period hi
  call wait30frames
  xor a
  ldh [rNR32],a  ; clear volume
  ret

wait30frames:
  ld a,%10111101
  ldh [rBGP],a
  ldh [rOBP0],a
  ld a,$84
  ldh [rBCPS],a
  ld a,$18
  ldh [rBCPD],a
  xor a
  ldh [rBCPD],a

  ld b,30
  .frameloop:
    call wait_vblank_irq
    dec b
    jr nz,.frameloop
  ld a,%01101100
  ldh [rBGP],a
  ldh [rOBP0],a
  ld hl,helpbgpalette_gbc
  ld bc,(8) * 256 + low(rBCPS)
  ld a,$80
  jp set_gbc_palette

PULSE_1K = 2048-131

soundtest_1kpulse:
  ld a,$80
  ldh [rNR11],a  ; Duty 50%
  ld a,$A0
  ldh [rNR12],a  ; volume and decay
  ld a,low(PULSE_1K)
  ldh [rNR13],a  ; freq lo
  ld a,high(PULSE_1K) | $80
  ldh [rNR14],a  ; freq hi and note start
  call wait30frames
  xor a
  ldh [rNR12],a  ; volume and decay
  ld a,$80
  ldh [rNR14],a  ; freq hi and note start
  ret

soundtest_hiss:
  ld a,$24
  jr soundtest_noise_a

soundtest_buzz:
  ld a,$2C
soundtest_noise_a:
  ldh [rNR43],a  ; freq lo
  ld a,$A0
  ldh [rNR42],a  ; volume and decay
  ld a,$80
  ldh [rNR44],a  ; freq hi and note start
  call wait30frames
  xor a
  ldh [rNR42],a  ; volume and decay
  ld a,$80
  ldh [rNR44],a  ; freq hi and note start
  ret

