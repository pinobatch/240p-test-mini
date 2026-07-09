.include "nes.inc"
.include "global.inc"
.import silence_10_ticks, silence_20_ticks, silence_a_ticks, wait_a_ticks
.import mdfourier_push_regs, load_pattern_y
.import apu_addressbuf, apu_databuf
.importzp test_section, test_row, test_ticksleft
.importzp test_subtype
.export mdfourier_push_apu, mdfourier_init_apu
.export pattern_y_data

; first 4 are defined in mdfourier_common.s
test_ticksleft2  = test_state+5
test_lastpulsehi = test_state+6
test_tableptr    = test_state+7

fds_wavebuf = $0140 + FDS_OFFSET

; FDS code and mapper configuration by Persune 2024
; with code from Brad Smith 2021
; https://github.com/bbbradsmith/NES-ca65-example/tree/fds

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.code
.endif

.align 32
.proc mdfourier_push_apu
  ; write wavetable first before writing other regs
  jsr mdfourier_push_fds_wavetable
  jmp mdfourier_push_regs
.endproc

.align 32
.proc mdfourier_push_fds_wavetable
  ldy fds_wavebuf+0
  bmi no_fds_tasks  ; wavetable data doesn't exceed #$3F
    ; write enable waveform
    lda #$80
    sta $4089
    ldx #$40
    fds_loop:
      lda fds_wavebuf-1,x   ; 4
      sta $403F,x           ; 5
      dex                   ; 2
      bne fds_loop          ; 3
    ; write protect waveform
    lda #$00
    sta $4089
    lda #$FF
    sta fds_wavebuf+0
  no_fds_tasks:
  rts
.endproc

.align 32
; pushes mod table to the FDS
; uses apu_databuf as a temporary buffer
.proc mdfourier_push_fds_modtable
    ; halt mod unit
    lda #$80
    sta $4087
    ldx #0
    fds_loop:
      lda apu_databuf,x     ; 4
      sta $4088             ; 5
      inx                   ; 2
      cpx #$20              ; 2
      bne fds_loop          ; 3
    ; reset mod counter
    lda #0
    sta $4085
  rts
.endproc

.align 32
; inits mod table to 0
.proc silence_modulator
    ; halt mod unit
    lda #$80
    sta $4087
    ldx #0
    txa
    fds_loop:
      sta $4088             ; 5
      inx                   ; 2
      cpx #$20              ; 2
      bne fds_loop          ; 3
    ; reset mod counter
    lda #0
    sta $4085
  rts
.endproc

.proc mdfourier_run
  jsr pattern_sync
  inc test_section

  ; Pattern being tested goes here
  ; jsr pattern_mastervol
  ; inc test_section
  ; rts

  ; Column 1
  lda #$00  ; sine
  jsr chromatic_scale_subtype_A
  inc test_section
  lda #$01  ; square
  jsr chromatic_scale_subtype_A
  inc test_section
  lda #$03  ; square 32x
  jsr chromatic_scale_subtype_A
  inc test_section

  jsr pattern_fds_pops
  inc test_section
  jsr pattern_phase_resets
  inc test_section
  lda #$00  ; sine
  jsr long_slide_channel_A
  inc test_section
  lda #$01  ; square
  jsr long_slide_channel_A
  inc test_section
  lda #$02  ; saw
  jsr long_slide_channel_A
  inc test_section
  lda #$03  ; square 32x
  jsr long_slide_channel_A
  inc test_section

  jsr pattern_db_fds
  inc test_section
  jsr pattern_2a03_phase_dac
  inc test_section
  jsr pattern_mastervol
  inc test_section
  jsr pattern_volume_envelopes
  inc test_section

  ; these tests require initializing the mod table
  jsr silence_modulator
  jsr pattern_modulation_test
  inc test_section
  jsr pattern_modulation_envelopes
  inc test_section

  ; fall through
skip_all:
.endproc

.proc pattern_sync
  jsr silence_20_ticks
  ; load sync waveform
  ldx #$40
  wavesyncloop:
    lda waveform_data_sync-1,x
    sta fds_wavebuf-1,x
    dex
    bne wavesyncloop

  lda #10
  sta test_ticksleft
  syncloop:
    ldy #syncon_data - pattern_y_data
    jsr load_pattern_y
    jsr mdfourier_present
    ldy #syncoff_data - pattern_y_data
    jsr load_pattern_y
    jsr mdfourier_present
    dec test_ticksleft
    bne syncloop
  jmp silence_20_ticks
.endproc

mdfourier_ready_tone = pattern_sync

;;
; Loads the silence pattern into the address and data buffer
.proc mdfourier_init_apu
  lda #$FF
  sta fds_wavebuf+0
  ldy #silence_data - pattern_y_data
  jmp load_pattern_y
.endproc

.proc chromatic_scale_subtype_A
  sta test_subtype
  tay
  lda #0
  sta test_row
  lda wavetable_table_lo,y
  sta test_tableptr
  lda wavetable_table_hi,y
  sta test_tableptr+1
  ldy #$40
  waveloop:
    lda (test_tableptr),y
    sta fds_wavebuf-1,y
    dey
    bne waveloop

  ldy #fds_note_data - pattern_y_data
  jsr load_pattern_y

  loop:
    ldx test_row
    lda fdsPeriodTableLo,x
    sta apu_databuf+1
    lda fdsPeriodTableHi,x
    sta apu_databuf+2
    
    lda #10
    jsr wait_a_ticks

    ; reset
    lda #$80
    sta apu_addressbuf+0
    inc test_row
    lda test_row
    cmp #94
    bcc loop
  jmp silence_10_ticks
.endproc

.proc pattern_fds_pops
  jsr silence_20_ticks
  ldy #$3F
  jsr fds_pop_y_wait_20
  ldy #$00
  jsr fds_pop_y_wait_20
  lda #30
  jmp silence_a_ticks
.endproc
.proc fds_pop_y_wait_20
  lda #20
.endproc
.proc fds_pop_y_wait_a
  ; write single byte of waveform
  sty apu_databuf+2
  ; reset phase
  ldy #$83
  sty apu_addressbuf+0
  ldy #$00
  sty apu_databuf+0
  ; write enable wavetable
  ldy #$89
  sty apu_addressbuf+1
  ldy #$80
  sty apu_databuf+1
  ; write single byte of waveform
  ldy #$40
  sty apu_addressbuf+2
  ; write protect wavetable
  ldy #$89
  sty apu_addressbuf+3
  ldy #$00
  sty apu_databuf+3
  ; volume 32, waveform halted
  ldy #$80
  sty apu_addressbuf+4
  ldy #$A0
  sty apu_databuf+4
  ldy #$83
  sty apu_addressbuf+5
  ldy #$00
  sty apu_databuf+5
  ldy #$FF
  sty apu_addressbuf+6
  jmp wait_a_ticks
.endproc

.proc pattern_phase_resets
  ; load sine waveform
  ldx #$40
  waveloop:
    lda waveform_data_sine-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ; Phase reset each tick
  ldy #phase_reset_data - pattern_y_data
  jsr load_pattern_y
  lda #20
  sta test_ticksleft
  loop:
    lda phase_reset_data
    sta apu_addressbuf+0
    ldx #69
    lda fdsPeriodTableLo,x
    sta apu_databuf+2
    lda fdsPeriodTableHi,x
    sta apu_databuf+3
    jsr mdfourier_present
    dec test_ticksleft
    bne loop
  jmp silence_20_ticks
.endproc

.proc long_slide_channel_A
  sta test_subtype
  tay
  lda wavetable_table_lo,y
  sta test_tableptr
  lda wavetable_table_hi,y
  sta test_tableptr+1

  ldy #$40
  waveloop:
    lda (test_tableptr),y
    sta fds_wavebuf-1,y
    dey
    bne waveloop

  ldy #fds_note_data - pattern_y_data
  jsr load_pattern_y

  ; use apu_databuf to hold frequency in memory
  lda fdsPeriodTableLo
  sta apu_databuf+1
  lda fdsPeriodTableHi
  sta apu_databuf+2

  ; FamiTracker applies a pitch slide effect to a note's first tick
  jsr addperiod
  lda #(560/20)
  sta test_ticksleft

  ; 560 ticks increasing period
  loop:
    lda #20
    sta test_ticksleft2
    inner:
      jsr mdfourier_present
      ; reset
      lda #$80
      sta apu_addressbuf+0
      jsr addperiod
      dec test_ticksleft2
      bne inner
    dec test_ticksleft
    bne loop

  jmp silence_10_ticks

  ; adds $8 to 12-bit period in apu_databuf+1
  addperiod:
    clc
    lda apu_databuf+1
    adc #8
    sta apu_databuf+1
    lda apu_databuf+2
    adc #0
    sta apu_databuf+2
    cmp #$10
    bne skipoverflow
    lda #$FF
    sta apu_databuf+1
    lda #$0F
    sta apu_databuf+2
  skipoverflow:
    rts
.endproc

.proc pattern_db_fds
  ldx #$40
  waveloop:
    lda waveform_data_square-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ldy #fds_note_data - pattern_y_data
  jsr load_pattern_y

  ; 2 seconds of FDS square note
  ldx #69
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  lda #120
  jsr wait_a_ticks

  lda #60
  jsr silence_a_ticks

  ldy #db_fds_2A03_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #36
  lda periodTableLo,x
  sta apu_databuf+1
  lda periodTableHi,x
  sta apu_databuf+2

  lda #120
  jsr wait_a_ticks

  lda #60
  jmp silence_a_ticks
.endproc

.proc pattern_2a03_phase_dac
  ldx #$40
  waveloop:
    lda waveform_data_saw-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ldy #fds_note_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #36
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2

  lda #30
  jsr wait_a_ticks

  jsr silence_10_ticks

  ldy #db_fds_2A03_data - pattern_y_data ; pitch and duty cycle gets overwritten
  jsr load_pattern_y

  lda #$7F
  sta apu_databuf+0
  lda periodTableLo,x
  sta apu_databuf+1
  lda periodTableHi,x
  sta apu_databuf+2

  lda #30
  jsr wait_a_ticks

  jsr silence_10_ticks

  ldx #$40
  waveloop2:
    lda waveform_data_sortedsaw-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop2

  ldy #fds_note_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #36
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2

  lda #30
  jsr wait_a_ticks

  jmp silence_10_ticks
.endproc

.proc pattern_mastervol
  lda #0
  sta test_subtype
  ldx #$40
  waveloop:
    lda waveform_data_saw-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  loop:
    ldy #fds_vol_env_disabled_master_data - pattern_y_data
    jsr load_pattern_y
    lda #$00
    sta apu_databuf+1
    lda #$01
    sta apu_databuf+2
    lda test_subtype
    and #3
    sta apu_databuf+3
    lda #40
    jsr wait_a_ticks
    inc test_subtype
    lda test_subtype
    cmp #4
    bne loop

  lda #10
  jmp silence_a_ticks
.endproc

.proc pattern_volume_envelopes
  ldx #$40
  waveloop:
    lda waveform_data_saw-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ; manual volume fade
  ldy #fds_vol_env_disabled_master_data - pattern_y_data
  jsr load_pattern_y
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2

  lda #32
  sta test_ticksleft
  volumeloop:
    lda test_ticksleft
    ora #$80
    sta apu_databuf+0
    jsr mdfourier_present
    lda #$80 ; reset
    sta apu_addressbuf+0
    dec test_ticksleft
    bne volumeloop
  lda #8
  jsr silence_a_ticks

  ; hardware volume fade decrease
  ldy #fds_vol_env_decrease_master_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2

  lda #40-3
  jsr wait_a_ticks
  lda #3
  jsr silence_a_ticks

  ; hardware volume fade increase
  ldy #fds_vol_env_increase_master_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2

  lda #40-6
  jsr wait_a_ticks
  lda #20+6
  jsr silence_a_ticks

  ; manual volume fade for volume gain 1
  ldy #fds_vol_env_disabled_master_data - pattern_y_data
  jsr load_pattern_y
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  lda #1
  ora #$80
  sta apu_databuf+0
  lda #1
  jsr wait_a_ticks
  lda #1+10
  jsr silence_a_ticks

  ; hardware volume fade decrease for volume gain 1
  ldy #fds_vol_env_decrease_master_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  lda #1
  ora #$80
  sta apu_databuf+3

  lda #2
  jsr wait_a_ticks
  lda #10-1 ; tick 1 frame earlier, we need time to reset phase first
  jsr silence_a_ticks

  ; DC offset master vol
  ; master volume
  lda #$89
  sta apu_addressbuf+0
  lda test_subtype
  and #3
  sta apu_databuf+0
  ; write enable wavetable
  lda #$89
  sta apu_addressbuf+1
  lda #$80
  sta apu_databuf+1
  ; write single byte of waveform
  lda #$40
  sta apu_addressbuf+2
  lda #$3F
  sta apu_databuf+2
  ; write protect wavetable
  lda #$89
  sta apu_addressbuf+3
  lda #$00
  sta apu_databuf+3
  ; reset phase
  lda #$83
  sta apu_addressbuf+4
  lda #$00
  sta apu_databuf+4
  ; volume 0, waveform halted
  lda #$80
  sta apu_addressbuf+5
  lda #$80
  sta apu_databuf+5
  lda #$83
  sta apu_addressbuf+6
  lda #$00
  sta apu_databuf+6
  lda #$FF
  sta apu_addressbuf+7

  jsr mdfourier_present

  ; volume 32, waveform halted
  lda #$80
  sta apu_addressbuf+0
  lda #$A0
  sta apu_databuf+0
  lda #$83
  sta apu_addressbuf+1
  lda #$00
  sta apu_databuf+1
  lda #$FF
  sta apu_addressbuf+2

  lda #32
  sta test_ticksleft
  volumeloop2:
    lda test_ticksleft
    ora #$80
    sta apu_databuf+0
    jsr mdfourier_present
    lda #$80 ; reset
    sta apu_addressbuf+0
    dec test_ticksleft
    bne volumeloop2

  lda #8
  jmp silence_a_ticks
.endproc

.proc pattern_modulation_test
  ldx #$40
  waveloop:
    lda waveform_data_sine-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ; a. sine wave, FT "NEZPlug" mod sine, mod depth of $3F, mod period
  ;    of $265. This checks for mod table index sync.
  ; b. sine wave, Dn-FT mod sine, mod depth of $3F, mod period
  ;    of $265. This checks against previous wave.
  lda #2
  sta test_ticksleft2
  loop:
    dec test_ticksleft2
    ; write to modulation table
    ldy test_ticksleft2
    lda modtable_table_lo+0,y
    sta test_tableptr+0
    lda modtable_table_hi+0,y
    sta test_tableptr+1
    ldy #$20
    modloop:
      lda (test_tableptr),y
      sta apu_databuf-1,y
      dey
      bne modloop
    jsr mdfourier_push_fds_modtable

    ldy #fds_note_data_mod - pattern_y_data
    jsr load_pattern_y
    ldy #60
    lda fdsPeriodTableLo,y
    sta apu_databuf+1
    lda fdsPeriodTableHi,y
    sta apu_databuf+2
        
    ; modulation depth
    lda #$3F
    ora apu_databuf+4
    sta apu_databuf+4
    ; modulation period
    ldy #60
    lda fdsPeriodTableLo,y
    sta apu_databuf+5
    lda fdsPeriodTableHi,y
    sta apu_databuf+6

    lda #30
    jsr wait_a_ticks
    jsr silence_10_ticks
    lda test_ticksleft2
    bne loop

  ; c. sine wave, modtable_data_mod_reset, mod depth of $10, mod period of $010.
  ;    This checks for mod counter reset.
  ; d. sine wave, modtable_data_mod_overflow, mod depth of $10, mod period of $010
  ; e. sine wave, modtable_data_mod_underflow, mod depth of $10, mod period of $010

  lda #3
  sta test_ticksleft2
  loop2:
    dec test_ticksleft2
    ; write to modulation table
    ldy test_ticksleft2
    lda modtable_table_lo+2,y
    sta test_tableptr+0
    lda modtable_table_hi+2,y
    sta test_tableptr+1
    ldy #$20
    modloop2:
      lda (test_tableptr),y
      sta apu_databuf-1,y
      dey
      bne modloop2
    jsr mdfourier_push_fds_modtable

    ldy #fds_note_data_mod - pattern_y_data
    jsr load_pattern_y
    ldy #60
    lda fdsPeriodTableLo,y
    sta apu_databuf+1
    lda fdsPeriodTableHi,y
    sta apu_databuf+2

    ; modulation depth
    lda #$10
    ora apu_databuf+4
    sta apu_databuf+4
    ; modulation period
    ldy #60
    lda #$20
    sta apu_databuf+5
    lda #$00
    sta apu_databuf+6

    lda #30
    jsr wait_a_ticks
    jsr silence_10_ticks
    lda test_ticksleft2
    bne loop2

  ; f. sine wave, modtable_data_mod_halt, mod depth of $10, mod period of $010.
  ;    in addition to $4085=$20, this will check for $4087.7 latch delay
  ; write to modulation table
  ldx #$20
  modloop3:
    lda modtable_data_sine_nezplug-1,x
    sta apu_databuf-1,x
    dex
    bne modloop3
  jsr mdfourier_push_fds_modtable

  ldy #fds_note_data_mod_halt - pattern_y_data
  jsr load_pattern_y
  ldy #60
  lda fdsPeriodTableLo,y
  sta apu_databuf+1
  lda fdsPeriodTableHi,y
  sta apu_databuf+2

  ; modulation depth
  lda #$3F
  ora apu_databuf+4
  sta apu_databuf+4
  ; modulation period
  ldy #60
  lda fdsPeriodTableLo,y
  sta apu_databuf+5
  lda fdsPeriodTableHi,y
  ora apu_databuf+6
  sta apu_databuf+6

  lda #30
  jsr wait_a_ticks
  jsr silence_modulator
  jmp silence_10_ticks
.endproc

.proc pattern_modulation_envelopes
  ; load saw waveform
  ldx #$40
  waveloop:
    lda waveform_data_saw-1,x
    sta fds_wavebuf-1,x
    dex
    bne waveloop

  ldx #$20
  modtableloop:
    lda modtable_data_mod_env-1,x
    sta apu_databuf-1,x
    dex
    bne modtableloop
  jsr mdfourier_push_fds_modtable

  ; manual mod fade
  ldy #fds_mod_env_disabled_master_data - pattern_y_data
  jsr load_pattern_y
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  ; modulation period
  lda #$20
  sta apu_databuf+3
  lda #$00
  sta apu_databuf+4

  lda #64
  sta test_ticksleft
  volumeloop:
    dec test_ticksleft
    ; modulation depth
    lda test_ticksleft
    ora #$80
    sta apu_databuf+5
    jsr mdfourier_present
    lda #$80 ; reset
    sta apu_addressbuf+0
    lda test_ticksleft
    bne volumeloop
  lda #70-64
  jsr wait_a_ticks
  jsr silence_10_ticks

  ; hardware mod fade decrease
  ldy #fds_mod_env_decrease_master_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  ; modulation period
  lda #$20
  sta apu_databuf+3
  lda #$00
  sta apu_databuf+4

  lda #70
  jsr wait_a_ticks
  jsr silence_10_ticks

  ; hardware mod fade increase
  ldy #fds_mod_env_increase_master_data - pattern_y_data
  jsr load_pattern_y
  
  ldx #72
  lda fdsPeriodTableLo,x
  sta apu_databuf+1
  lda fdsPeriodTableHi,x
  sta apu_databuf+2
  ; modulation period
  lda #$20
  sta apu_databuf+3
  lda #$00
  sta apu_databuf+4

  lda #70
  jsr wait_a_ticks
  jsr silence_modulator
  jmp silence_10_ticks
  
  ; TODO: measure exact envelope length by writing to $4080 and
  ; counting cycles
.endproc

.ifdef FDSHEADER
.segment "FILE0_DAT"
.else
.rodata
.endif

pattern_y_data:
silence_data:
  ; Silence pulses, reset their phase, and disable sweep
  .dbyt $00B0, $04B0, $0108, $0508, $0200, $0600, $0300, $0700
  ; Silence triangle and noise
  .dbyt $0800, $0CB0
  ; Silence DPCM, set highest pitch and default level,
  ; and enable other channels (which were just set silent)
  .dbyt $100F, $1100, $150F
  ; Reset APU length counter
  .dbyt $1780
  ; init 
  .dbyt $2300, $2383
  ; Disable FDS volume envelope and silence volume
  .dbyt $8080
  ; Clear FDS frequency, halt waveform
  ; and disable volume and sweep envelopes
  .dbyt $83C0, $8200
  ; Init FDS envelope speed
  .dbyt $8AFF
  ; Disable modulation
  .dbyt $8600, $8780, $8480
  .byte $FF

syncon_data:
  ; 1 kHz 8x square wave
  .dbyt $80A0, $83C0, $8227, $8309
  .byte $FF

syncoff_data:
  ; 1 kHz 8x square wave, phase reset
  .dbyt $8080, $83C0, $8200, $8300
  .byte $FF

phase_reset_data:
  .dbyt $80A0, $83C0, $8200, $8300
  .byte $FF

fds_note_data:
  .dbyt $80A0, $8200, $8300
  .byte $FF

; volume gain 32, wave frequency, mod speed of 7, mod gain of x, mod freq
fds_note_data_mod:
  .dbyt $80A0, $8200, $8300, $8407, $8480, $8600, $8700
  .byte $FF

; volume gain 32, wave frequency, mod speed of 7, mod gain of x,
; mod freq with mod table counter update halt
fds_note_data_mod_halt:
  .dbyt $80A0, $8200, $8300, $8407, $8480, $8600, $8780, $8520
  .byte $FF

; volume gain 32, enable decreasing volume envelope, reset phase, pitch, vol
; envelope speed and master env speed chosen to match NTSC frame rate
fds_vol_env_decrease_master_data:
  .dbyt $8A48, $8200, $8300, $80A0, $8032
  .byte $FF

; volume gain 32, enable increasing volume envelope, reset phase, pitch, vol
; envelope speed and master env speed chosen to match NTSC frame rate
fds_vol_env_increase_master_data:
  .dbyt $8A48, $8200, $8300, $8080, $8072
  .byte $FF

; volume gain 32, disabled volume envelope, pitch, master vol
fds_vol_env_disabled_master_data:
  .dbyt $80A0, $8200, $8300, $8900
  .byte $FF

; volume gain 32, enable decreasing mod envelope, reset phase, pitch, mod 
; envelope speed and master env speed chosen to match NTSC frame rate
fds_mod_env_decrease_master_data:
  .dbyt $80A0, $8200, $8300, $8600, $8700, $8A48, $84BF, $8432
  .byte $FF

; volume gain 32, enable increasing mod envelope, reset phase, pitch, mod
; envelope speed and master env speed chosen to match NTSC frame rate
fds_mod_env_increase_master_data:
  .dbyt $80A0, $8200, $8300, $8600, $8700, $8A48, $84C0, $8472
  .byte $FF

; volume gain 32, wave freq, disabled mod envelope
fds_mod_env_disabled_master_data:
  .dbyt $80A0, $8200, $8300, $8600, $8700, $8480
  .byte $FF

db_fds_2A03_data:
  .dbyt $00BF, $0200, $0300
  .byte $FF

.out .sprintf("%d of 256 pattern_y_data bytes used", * - pattern_y_data)

; decremented pointer location for faster loop index
wavetable_table_lo:
  .byte <(waveform_data_sine      -1)
  .byte <(waveform_data_square    -1)
  .byte <(waveform_data_saw       -1)
  .byte <(waveform_data_squarex32 -1)
  .byte <(waveform_data_sortedsaw -1)
  .byte <(waveform_data_sync      -1)
wavetable_table_hi:
  .byte >(waveform_data_sine      -1)
  .byte >(waveform_data_square    -1)
  .byte >(waveform_data_saw       -1)
  .byte >(waveform_data_squarex32 -1)
  .byte >(waveform_data_sortedsaw -1)
  .byte >(waveform_data_sync      -1)

modtable_table_lo:
  .byte <(modtable_data_sine         -1)
  .byte <(modtable_data_sine_nezplug -1)
  .byte <(modtable_data_mod_underflow-1)
  .byte <(modtable_data_mod_overflow -1)
  .byte <(modtable_data_mod_reset    -1)
  .byte <(modtable_data_mod_halt     -1)
  .byte <(modtable_data_mod_env      -1)
modtable_table_hi:
  .byte >(modtable_data_sine         -1)
  .byte >(modtable_data_sine_nezplug -1)
  .byte >(modtable_data_mod_underflow-1)
  .byte >(modtable_data_mod_overflow -1)
  .byte >(modtable_data_mod_reset    -1)
  .byte >(modtable_data_mod_halt     -1)
  .byte >(modtable_data_mod_env      -1)

waveform_data_sine:
  .byte $21, $24, $27, $2A, $2D, $30, $32, $35, $37, $39, $3B, $3C, $3D, $3E, $3F, $3F
  .byte $3F, $3F, $3E, $3D, $3C, $3B, $39, $37, $35, $32, $30, $2D, $2A, $27, $24, $21
  .byte $1E, $1B, $18, $15, $12, $0F, $0D, $0A, $08, $06, $04, $03, $02, $01, $00, $00
  .byte $00, $00, $01, $02, $03, $04, $06, $08, $0A, $0D, $0F, $12, $15, $18, $1B, $1E

waveform_data_square:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F
  .byte $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F

waveform_data_saw:
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  .byte $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F
  .byte $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F
  .byte $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F

waveform_data_squarex32:
  .byte $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F
  .byte $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F
  .byte $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F
  .byte $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F, $00, $3F

waveform_data_sortedsaw:
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $10
  .byte $0F, $11, $12, $13, $14, $15, $16, $18, $17, $19, $1A, $1B, $1C, $20, $1D, $21
  .byte $1E, $22, $24, $23, $1F, $25, $26, $28, $27, $29, $2A, $2C, $2B, $30, $2D, $2E
  .byte $31, $32, $2F, $34, $33, $35, $36, $38, $39, $37, $3A, $3C, $3B, $3D, $3E, $3F

waveform_data_sync:
  .byte $00, $00, $00, $00, $3F, $3F, $3F, $3F, $00, $00, $00, $00, $3F, $3F, $3F, $3F
  .byte $00, $00, $00, $00, $3F, $3F, $3F, $3F, $00, $00, $00, $00, $3F, $3F, $3F, $3F
  .byte $00, $00, $00, $00, $3F, $3F, $3F, $3F, $00, $00, $00, $00, $3F, $3F, $3F, $3F
  .byte $00, $00, $00, $00, $3F, $3F, $3F, $3F, $00, $00, $00, $00, $3F, $3F, $3F, $3F

modtable_data_sine:
  .byte 4, 7, 7, 7, 7, 7, 7, 0, 0, 0, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 0, 0, 0, 7, 7, 7, 7, 7, 7

modtable_data_sine_nezplug:
  .byte 7, 7, 7, 7, 7, 7, 7, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 7, 7, 7, 7, 7, 7

modtable_data_mod_overflow:
  .repeat 32
    .byte 1
  .endrepeat

modtable_data_mod_underflow:
  .repeat 32
    .byte 7
  .endrepeat

modtable_data_mod_reset:
  .byte 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

modtable_data_mod_halt:
  .repeat 32
    .byte 5
  .endrepeat

modtable_data_mod_env:
  .repeat 16
  .byte 4, 3
  .endrepeat
