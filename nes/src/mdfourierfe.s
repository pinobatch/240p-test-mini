.include "nes.inc"
.include "global.inc"
.importzp helpsect_mdfourier

.proc do_mdfourier
  jsr mdfourier_init_apu
  jsr read_pads
  jsr mdfourier_present
  ldx #helpsect_mdfourier
  lda #KEY_LEFT|KEY_RIGHT|KEY_B|KEY_A|KEY_START
  jsr helpscreen
  lda new_keys
  and #KEY_A|KEY_START
  beq done
  jsr mdfourier_run
  jmp do_mdfourier
done:
  rts
.endproc

.proc mdfourier_present
  lda cur_keys+0
  and #KEY_B
  bne skip_it_all
  
  lda nmis
  :
    cmp nmis
    beq :-
  jsr mdfourier_push_apu
  jsr read_pads
skip_it_all:
  rts
.endproc

