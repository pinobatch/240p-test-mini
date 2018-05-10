;
; Placeholder move routine for Game Boy
;
; Copyright 2018 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

include "src/gb.inc"
include "src/global.inc"

SECTION "rom_bg", ROM0

; game loop

lame_boy_demo::
  xor a
  ld [help_bg_loaded],a

  ld a,bank(bggfx_chr)
  ld [rMBC1BANK1],a

  ; This part doesn't use rSTAT IRQ
  ld a,IEF_VBLANK
  ldh [rIE],a  ; enable rSTAT IRQ
  call draw_bg
  call load_player_cels

  ; Can turn on LCD at any time.  Only on->off transitions must
  ; happen in vblank.  But because GB asserts no vblank IRQ in
  ; forced blanking, set palette to white until shadow OAM is valid.
  ld a,LCDCF_ON|OBJ_ON|BG_NT0|BG_CHR21
  ldh [rLCDC],a
  ld [vblank_lcdc_value],a
  xor a
  ld [rBGP],a
  ld [rOBP0],a
  ld [rOBP1],a

.loop:
  ld b,helpsect_lame_boy
  call read_pad_help_check
  jr nz,lame_boy_demo

  call move_player

  ; First make sure it doesn't crash
  xor a
  ld [oam_used],a
  call draw_player_sprite
  call lcd_clear_oam

  ; And present everything
  call wait_vblank_irq
  call run_dma

  ; Set palettes
  ld a, %01101100
  ldh [rBGP],a
  ld a, %00011110
  ldh [rOBP0],a

  ; Show vblank counter
  ld hl,_SCRN0
  ld a,[nmis]
  push af
  swap a
  and $0F
  or $10
  ld [hl+],a
  pop af
  and $0F
  or $10
  ld [hl],a

  ld a,[nmis]
  call bcd8bit
  ld hl,_SCRN0+32
  ld b,a
  swap a
  and $0F
  or $10
  ld [hl+],a
  ld a,b
  and $0F
  or $10
  ld [hl+],a
  ld a,c
  and $0F
  or $10
  ld [hl],a

  ld a,[new_keys]
  bit PADB_B,a
  jr z,.loop
  ret

; Background drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_bg:
  call lcd_off

  ; Fill CHR RAM
  ld de,bggfx_chr
  ld hl,CHRRAM2
  ld bc,32
  call pb16_unpack_block

  ; Clear nametable excl. floor
  ld h,$00
  ld de,_SCRN0
  ld bc,32*16
  call memset

  ; Draw top of floor
  ld h,$0B
  ld de,_SCRN0+32*16
  ld bc,20
  call memset
  
  ; Draw bottom of floor
  ld h,$01
  ld de,_SCRN0+32*17
  ld bc,20
  call memset

  ld hl,_SCRN0+32*12+1
  call bg_draw_one_block
  ld hl,_SCRN0+32*14+1
  call bg_draw_one_block
  ld hl,_SCRN0+32*12+17
  call bg_draw_one_block
  ld hl,_SCRN0+32*14+17
  call bg_draw_one_block

  ; Make VWF window
  ld a,$60
  ld hl,_SCRN0+32*0+4
.vwffill1:
  ld [hl+],a
  inc a
  cp $70
  jr nz,.vwffill1
  ld hl,_SCRN0+32*1+4
.vwffill2:
  ld [hl+],a
  inc a
  cp $80
  jr nz,.vwffill2

  ; Write initial A and B values and result of Super Game Boy test
  ld hl,help_line_buffer
  ld a,"A"
  ld [hl+],a
  ld a,":"
  ld [hl+],a
  ld a,[initial_a]
  call puthex
  ld a," "
  ld [hl+],a
  ld a,"B"
  ld [hl+],a
  ld a,":"
  ld [hl+],a
  ld a,[initial_b]
  call puthex
  ld a," "
  ld [hl+],a
  ld a,"S"
  ld [hl+],a
  ld a,":"
  ld [hl+],a
  ld a,[is_sgb]
  call puthex
  xor a
  ld [hl],a

  ; Draw the text
  call vwfClearBuf
  ld hl,help_line_buffer
  ld b,4
  call vwfPuts
  ld hl,CHRRAM2+$60*16
  ld b,$00
  call vwfPutBuf03

  ; Write random numbers
  ld bc,1
  call srand
  ld c,4
  ld hl,help_line_buffer
  ld a,"r"
  ld [hl+],a
  ld a,"a"
  ld [hl+],a
  ld a,"n"
  ld [hl+],a
  ld a,"d"
  ld [hl+],a
  ld a,":"
  ld [hl+],a
.randloop:
  ld a," "
  ld [hl+],a
  push bc
  push hl
  call rand
  pop hl
  ld a,b
  call puthex
  ld a,c
  call puthex
  pop bc
  dec c
  jr nz,.randloop
  xor a
  ld [hl],a

  ; Draw the text
  call vwfClearBuf
  ld hl,help_line_buffer
  ld b,4
  call vwfPuts
  ld hl,CHRRAM2+$70*16
  ld b,$00
  call vwfPutBuf03

  ; Expects palette %01101100
  ret

bg_draw_one_block:
  ld a,$0C
  ld [hl+],a
  inc a
  ld [hl-],a
  inc a
  set 5,l
  ld [hl+],a
  inc a
  ld [hl-],a
  inc a
  ret

;;
; Writes two hex nibbles ("0123456789ABCDEF") to HL
puthex::
  push af
  swap a
  and $0F
  call putnibble
  pop af
  and $0F
putnibble::
  cp $0A
  jr c,.not_letter
  add ("A"-"9"-1)
.not_letter:
  add "0"
  ld [hl+],a
  ret

SECTION "ram_player", WRAM0
player_xsub: ds 1
player_x: ds 1
player_dxsub: ds 1
player_frame_sub: ds 1
player_frame: ds 1
player_facing: ds 1

SECTION "rom_player", ROM0

; Player movement ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WALK_SPD equ 105  ; speed limit in 1/256 px/frame
WALK_ACCEL equ 4  ; movement acceleration in 1/256 px/frame^2
WALK_BRAKE equ 8  ; stopping acceleration in 1/256 px/frame^2

LEFT_WALL equ 24
RIGHT_WALL equ 136

move_player::
  ld a,[cur_keys]
  ld e,a

  ; Accelerate to right only if the player is holding right
  ; on the Control Pad and has a nonnegative velocity.
  ld a,[player_dxsub]
  bit PADB_RIGHT,e
  jr z,.notRight
  bit 7,a
  jr nz,.notRight
  
  ; Right is pressed. Add to velocity but don't allow it to exceed maximum.
  add WALK_ACCEL
  cp WALK_SPD
  jr c,.walk_speed_not_maxed
  ld a,WALK_SPD
.walk_speed_not_maxed:
  ld [player_dxsub],a
  ld hl,player_facing
  res BOAM_HFLIP,[hl]
  jr .doneRight
.notRight:

  ; Right is not pressed. Brake if headed right.  
  bit 7,a
  jr nz,.doneRight
  cp WALK_BRAKE
  jr nc,.notRightStop
  ld a,WALK_BRAKE
.notRightStop:
  sub WALK_BRAKE
  ld [player_dxsub],a
.doneRight:

  ; Accelerate to left only if the player is holding left
  ; on the Control Pad and has a nonpositive velocity.
  ld a,[player_dxsub]
  bit PADB_LEFT,e
  jr z,.notLeft
  or a
  jr z,.isLeft
  bit 7,a
  jr z,.notLeft
.isLeft:
  ; Left is pressed.  Subtract from velocity.
  sub WALK_ACCEL
  cp 256-WALK_SPD
  jr nc,.walk_speed_not_neg_maxed
  ld a,256-WALK_SPD
.walk_speed_not_neg_maxed:
  ld [player_dxsub],a
  ld hl,player_facing
  set BOAM_HFLIP,[hl]
  jr .doneLeft

  ; Left is not pressed.  Brake if headed left.
.notLeft:
  bit 7,a
  jr z,.doneLeft
  cp 256-WALK_BRAKE
  jr c,.notLeftStop
  ld a,256-WALK_BRAKE
.notLeftStop:
  add WALK_BRAKE
  ld [player_dxsub],a

.doneLeft:

  ; Move the player by adding the velocity (in de) to the position
  ; (in hl)
  ld a,[player_dxsub]
  ld e,a
  
  ; Idiom for sign extension, per ISSOtm in
  ; http://gbdev.gg8.se/forums/viewtopic.php?pid=3171#p3171
  ; which works because subtraction carry on 8080 is inverted
  ; compared to 6502/ARM (C true = -1)
  rla ; Bit 7 into carry
  sbc a, a ; $00 if no carry, $FF if carry
  ld d, a

  ld a,[player_xsub]
  ld l,a
  ld a,[player_x]
  ld h,a
  add hl,de
  
  ; Test for collision with side walls
  ld a,h
  cp LEFT_WALL-4
  jr nc,.notHitLeft
  ld h,LEFT_WALL-4
  ld e,0
  jr .doneWallCollision
.notHitLeft:
  cp RIGHT_WALL-12
  jr c,.notHitRight
  ld h,RIGHT_WALL-13
  ld e,0
.notHitRight:
.doneWallCollision:

  ; Write back new velocity
  ld a,l
  ld [player_xsub],a
  ld a,h
  ld [player_x],a
  ld a,e
  ld [player_dxsub],a

  ; Animate the player
  ; If stopped, freeze the animation on frame 0
  or a
  jr nz, .notStop1
  ld a,$C0
  ld [player_frame_sub],a
  xor a
  jr .have_player_frame
.notStop1:

  ; Take absolute value of velocity (negate it if it's negative)
  bit 7,a
  jr z,.player_animate_noneg
  cpl
  inc a
.player_animate_noneg:

  ; Multiply abs(velocity) by 5/16
  ; Consider alternative by ISSOtm in
  ; http://gbdev.gg8.se/forums/viewtopic.php?pid=3171#p3171
  sra a
  sra a
  ld b,a
  sra a
  sra a
  adc b
  ld b,a

  ; 16-bit add it to player_frame
  ld a,[player_frame_sub]
  add b
  ld [player_frame_sub],a
  ld a,[player_frame]
  adc 0

  ; Wrap from $800 (after last frame of walk cycle)
  ; to $100 (first frame of walk cycle)
  cp 8
  jr c,.have_player_frame
  ld a,1
.have_player_frame:

  ld [player_frame],a
  ret

; Sprite drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PLAYER_Y = 128
PLAYER_TILE_BASE = $50

;;
; Initializes the player character's position and copies its tiles
; into CHR RAM bank 0 starting at PLAYER_TILE_BASE.
load_player_cels::
  ld a,40
  ld [player_x],a
  xor a
  ld [player_xsub],a
  ld [player_dxsub],a
  ld [player_facing],a

  ld de,spritegfx_chr
  ld hl,CHRRAM0+PLAYER_TILE_BASE*16
  ld b,48
  jp pb16_unpack_block


;;
; Adds six sprites representing the player character
; to the display list.
draw_player_sprite:

  ; Set up sprite parameters
  ld a,3
  ldh [Lspriterect_height],a
  dec a
  ldh [Lspriterect_width],a
  ld a,8
  ldh [Lspriterect_rowht],a
  add a
  ldh [Lspriterect_tilestride],a
  ld a,PLAYER_Y
  sub 24  ; ht
  add 16  ; sprite engine's top overscan
  ldh [Lspriterect_y],a
  ld a,[player_x]
  add a,8  ; Game Boy sprites start at X=8
  ldh [Lspriterect_x],a
  ld a,[player_facing]
  ldh [Lspriterect_attr],a
  ; The eight frames start at $10, $12, ..., $1E, where
  ; 0 is still and 1-7 are scooting.
  ld a,[player_frame]
  add a
  add PLAYER_TILE_BASE
  ldh [Lspriterect_tile],a
  jp draw_spriterect

draw_spriterect::
  rsset hLocals+8
Lx_add                 rb 1

  ; Set up increments based on flip value
  ldh a,[Lspriterect_attr]
  ld c,a
  ldh a,[Lspriterect_x]
  ld b,8
  bit 5,c  ; Attribute bit 5 is set if facing left
  jr z,.not_flipped
  ld d,a
  ldh a,[Lspriterect_width]
  dec a
  add a
  add a
  add a
  add d
  ld b,256-8
.not_flipped:
  ldh [Lspriterect_x],a
  ld a,b
  ldh [Lx_add],a

  ; Frame 7 is special: its hotspot is 1 unit forward.  Find which
  ; direction "forward" is.
  cp PLAYER_TILE_BASE + 7 * 2
  jr c,.not_frame_7
  ld b,1
  bit 5,c
  jr z,.f7_not_flipped
  ld b,low(-1)
.f7_not_flipped:
  ldh a,[Lspriterect_x]
  add b
  ldh [Lspriterect_x],a
.not_frame_7:

  ld h,high(SOAM)
  ld a,[oam_used]
  ld l,a
.rowloop:
  ldh a,[Lspriterect_width]
  ld b,a  ; B: remaining width on this row in 8px units
  ldh a,[Lspriterect_tile]
  ld d,a  ; D: current tile
  ldh a,[Lspriterect_x]
  ld e,a  ; E: current X
.tileloop:
  ; Draw an 8x8 pixel chunk of the character using one 4-byte entry
  ; in the display list.
  ldh a,[Lspriterect_y]
  ld [hl+],a
  ld a,e  ; X position of sprite
  ld [hl+],a
  ldh a,[Lx_add]
  add e
  ld e,a

  ld a,d  ; Tile number
  ld [hl+],a
  ; Go to next tile: add 2 if 8x16 or 1 if not
  inc d
  ld a,[vblank_lcdc_value]
  bit 2,a
  jr z,.not8x16
  inc d
.not8x16:

  ld a,c  ; Attribute
  ld [hl+],a
  dec b
  jr nz,.tileloop
  
  ; Move to the next row, which is 8 pixels down and on the next
  ; row of tiles in the pattern table.
  ldh a,[Lspriterect_y]
  ld b,a
  ldh a,[Lspriterect_rowht]
  add b
  ldh [Lspriterect_y],a
  ldh a,[Lspriterect_tile]
  ld b,a
  ldh a,[Lspriterect_tilestride]
  add b
  ldh [Lspriterect_tile],a
  ldh a,[Lspriterect_height]
  dec a
  ldh [Lspriterect_height],a
  jr nz,.rowloop
  
  ld a,l
  ld [oam_used],a
  ret

; CHR resources ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "placeholderchr",ROMX
bggfx_chr: incbin "obj/gb/bggfx.chrgb.pb16"
spritegfx_chr: incbin "obj/gb/spritegfx.chrgb.pb16"
