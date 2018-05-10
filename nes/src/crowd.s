; Crowd, by kragen, CC-BY
; http://canonical.org/~kragen/bytebeat/
;
; for (uint32 t = 0; ; ++t) {
;   uint8 out = 
;     ((t<<1)^((t<<1)+(t>>7)&t>>12))
;     | t>>(4-(1^7&(t>>19)))
;     | t>>7;
;   play(out >> 1);
; }
;
; Implemented for NES by rainwarrior, 3/13/2017
; after a suggestion by tepples

.export crowd

; Local variables
t0   = $00
t1   = $01
t2   = $02
t3   = $03
o    = $04
os   = $05
ol1  = $06
or7  = $07
or12 = $08
sj   = $09
sjmp = $0A

.segment "CODE"
crowd:
	lda #0
	sta t0
	sta t1
	sta t2
	sta t3
crowd_loop:
	;
	; increment
	;
	; t = t+1
	clc
	lda t0
	adc #1
	sta t0
	lda t1
	adc #0
	sta t1
	lda t2
	adc #0
	sta t2
	lda t3
	adc #0
	sta t3
	;
	; common values
	;
	; or7 = (t >> 7)
	lda t0
	rol
	lda t1
	rol
	sta or7
	; ol1 = (t << 1)
	lda t0
	asl
	sta ol1
	;
	; line 1
	;
	; or12 = (t>>12)
	lda t1
	asl
	asl
	asl
	asl
	sta or12
	lda t2
	ror
	ror or12
	ror
	ror or12
	ror
	ror or12
	ror
	ror or12
	; (t<<1)+(t>>7)
	lda ol1
	clc
	adc or7
	; ((t<<1)+(t>>7)&t>>12))
	and or12
	; ((t<<1)^((t<<1)+(t>>7)&t>>12))
	eor ol1
	;
	; line 3
	;
	; | t>>7
	ora or7
	sta o ; line 1 | line 3
	;
	; line 2
	;
	; 1^7&(t>>19)
	lda t2
	ror
	ror
	ror
	and #7
	eor #1
	sta sj ; not used, for debugging
	; t >> (4 - (1^7&(t>>19)))
	asl
	tax
	lda sj_table+0, X
	sta sjmp+0
	lda sj_table+1, X
	sta sjmp+1
	jmp (sjmp)
	; (sjmp) returns here
finish:
	ora o
	lsr
	sta $4011
	jmp crowd_loop

.align 8 ; prevent page crossing
sj_table:
	.addr sj0
	.addr sj1
	.addr sj2
	.addr sj3
	.addr sj4
	.addr sj5
	.addr sj6
	.addr sj7

sj0: ; (t >> 4) [ >> 1 ]
	lda t0
	asl ; 2 cycles each
	asl
	asl
	asl
	sta os
	lda t1
	ror    ; 2 cycles each
	ror os ; 5 cycles each
	ror
	ror os
	ror
	ror os
	ror
	ror os
	lda os
	; 48 cycles before the jump
	jmp finish

.macro sj_wait7
	nop
	nop
	lda os
.endmacro

sj1: ; (t >> 3)
	lda t0
	asl
	asl
	asl
	nop ; +2
	sta os
	lda t1
	ror
	ror os
	ror
	ror os
	ror
	ror os
	sj_wait7 ; +7
	lda os
	jmp finish

sj2: ; (t >> 2)
	lda t0
	asl
	asl
	nop ; +2
	nop ; +2
	sta os
	lda t1
	ror
	ror os
	ror
	ror os
	sj_wait7 ; +7
	sj_wait7 ; +7
	lda os
	jmp finish

sj3: ; (t >> 1)
	lda t1
	ror
	lda t0
	ror
	; 10 cycles
	; +38 = 48
	.repeat 38/2
		nop
	.endrepeat
	jmp finish

sj4: ; (t >> 0)
	lda t0
	; 3 cycles
	sta os ; +3
	; +42 = 48
	.repeat 42/2
		nop
	.endrepeat
	jmp finish

sj5: ; (t >> 31)
	lda t3
	rol
	rol
	and #1
	; 9 cycles
	sta os ; + 3
	; +36 = 48
	.repeat 36/2
		nop
	.endrepeat
	jmp finish

sj6: ; (t >> 30)
	lda t3
	rol
	rol
	rol
	and #3
	; 11 cycles
	sta os ; + 3
	; +34 = 48
	.repeat 34/2
		nop
	.endrepeat
	jmp finish

sj7: ; (t >> 29)
	lda t3
	rol
	rol
	rol
	rol
	and #7
	; 13 cycles
	sta os ; + 3
	; +32 = 48
	.repeat 32/2
		nop
	.endrepeat
	jmp finish

