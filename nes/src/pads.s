;
; NES controller reading code
; Copyright 2009-2018 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

;
; 2018-06: Save a byte in autorepeat
; 2011-07: Damian Yerrick added labels for the local variables and
;          copious comments and made USE_DAS a compile-time option
;

.export read_pads
.importzp cur_keys, new_keys

JOY1      = $4016
JOY2      = $4017

; turn USE_DAS on to enable autorepeat support
.ifndef USE_DAS
USE_DAS = 1
.endif
.ifndef USE_2P
USE_2P = 1
.endif

; time until autorepeat starts making keypresses
DAS_DELAY = 15
; time between autorepeat keypresses
DAS_SPEED = 3

; FDS code and mapper configuration by Persune 2023
; with code from Brad Smith 2021
; https://github.com/bbbradsmith/NES-ca65-example/tree/fds

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.segment "LIBCODE"
.endif
.proc read_pads
thisRead = $00
firstRead = $02
lastFrameKeys = $04

  ; store the current keypress state to detect key-down later
  lda cur_keys
  sta lastFrameKeys
  .if ::USE_2P
    lda cur_keys+1
    sta lastFrameKeys+1
  .endif

  ; Read the joypads twice in case DMC DMA caused a clock glitch.
  jsr read_pads_once
  lda thisRead
  sta firstRead
  .if ::USE_2P
    lda thisRead+1
    sta firstRead+1
  .endif
  jsr read_pads_once

  .if ::USE_2P

    ; For each player, make sure the reads agree, then find newly
    ; pressed keys.
    ldx #1
  @fixupKeys:

    ; If the player's keys read out the same way both times, update.
    ; Otherwise, keep the last frame's keypresses.
    lda thisRead,x
    cmp firstRead,x
    bne @dontUpdateGlitch
      sta cur_keys,x
    @dontUpdateGlitch:
  
    lda lastFrameKeys,x   ; A = keys that were down last frame
    eor #$FF              ; A = keys that were up last frame
    and cur_keys,x        ; A = keys down now and up last frame
    sta new_keys,x
    dex
    bpl @fixupKeys
  .else
    lda thisRead
    cmp firstRead
    bne @dontUpdateGlitch
      sta cur_keys
    @dontUpdateGlitch:
    lda lastFrameKeys   ; A = keys that were down last frame
    eor #$FF            ; A = keys that were up last frame
    and cur_keys        ; A = keys down now and up last frame
    sta new_keys
  .endif
  rts

read_pads_once:

  ; Write 1 then 0 to JOY1 to send a latch signal, telling the
  ; controllers to copy button states into a shift register.
  ; Then shift bits from the controllers into thisRead and
  ; thisRead+1.  In addition, thisRead+1 serves as the
  ; loop counter: once the $01 gets shifted left eight times,
  ; the 1 bit will end up in carry, terminating the loop.
  lda #$01
  sta JOY1
  sta thisRead+0
  lsr a
  sta JOY1
  loop:
    ; On NES and AV Famicom, button presses always show up in D0.
    ; On the original Famicom, presses on the hardwired controllers
    ; show up in D0 and presses on plug-in controllers show up in D1.
    ; D2-D7 consist of data from the Zapper, Power Pad, Vs. System
    ; DIP switches, and bus capacitance; ignore them.
    .if ::USE_2P
      lda JOY2       ; read player 2's controller
      and #%00000011 ; ignore D2-D7
      cmp #1         ; CLC if A=0, SEC if A>=1
      rol thisRead+1 ; put one bit in the register
    .endif
    lda JOY1         ; read player 1's controller the same way
    and #$03
    cmp #1
    rol thisRead+0
    bcc loop         ; once $01 has been shifted 8 times, we're done
  rts
.endproc


; Optional autorepeat handling

.if USE_DAS
.export autorepeat
.importzp das_keys, das_timer

;;
; Computes autorepeat (delayed-auto-shift) on the gamepad for one
; player, ORing result into the player's new_keys.
; @param X which player to calculate autorepeat for
.proc autorepeat
  ; If no keys are held, skip all autorepeat processing
  lda cur_keys,x
  beq no_das

  ; If any keys were newly pressed, set the eligible keys among them
  ; as the autorepeating set.  For example, changing from Up to
  ; Up+Right sets Right as the new autorepeating set.
  ; (Quirk: Going from 0 to Up+Right in one frame sets Up+Right
  ; as the autorepeating set.)
  lda new_keys,x
  beq no_restart_das
  sta das_keys,x
  lda #DAS_DELAY
  bne have_das_timer
no_restart_das:

  ; If time has expired, merge in the autorepeating set
  dec das_timer,x
  bne no_das
  lda das_keys,x
  and cur_keys,x
  ora new_keys,x
  sta new_keys,x
  lda #DAS_SPEED
have_das_timer:
  sta das_timer,x
no_das:
  rts
.endproc

.endif
