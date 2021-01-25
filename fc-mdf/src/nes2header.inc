;
; NES 2.0 header generator for ca65 (nes2header.inc)
; 
; Copyright 2016 Damian Yerrick
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

;;
; Puts ceil(log2(sz / 64)) in logsz, which should be
; local to the calling macro.  Used for NES 2 RAM sizes.
.macro _nes2_logsize sz, logsz
  .assert sz >= 0 .and sz <= 1048576, error, "RAM size must be 0 to 1048576"
  .if sz < 1
    logsz = 0
  .elseif sz <= 128
    logsz = 1
  .elseif sz <= 256
    logsz = 2
  .elseif sz <= 512
    logsz = 3
  .elseif sz <= 1024
    logsz = 4
  .elseif sz <= 2048
    logsz = 5
  .elseif sz <= 4096
    logsz = 6
  .elseif sz <= 8192
    logsz = 7
  .elseif sz <= 16384
    logsz = 8
  .elseif sz <= 32768
    logsz = 9
  .elseif sz <= 65536
    logsz = 10
  .elseif sz <= 131072
    logsz = 11
  .elseif sz <= 262144
    logsz = 12
  .elseif sz <= 524288
    logsz = 13
  .else
    logsz = 14
  .endif
.endmacro

;;
; Sets the PRG ROM size to sz bytes. Must be multiple of 16384;
; should be a power of 2.
; example: nes2prg 131072
.macro nes2prg sz
.local sz1
  sz1 = (sz) / 16384
_nes2_prgsize = <sz1
_nes2_prgsizehi = >sz1
.endmacro

;;
; Sets the CHR ROM size to sz bytes. Must be multiple of 8192;
; should be a power of 2.
; example: nes2chr 32768
.macro nes2chr sz
.local sz1
  sz1 = (sz) / 8192
_nes2_chrsize = <sz1
_nes2_chrsizehi = >sz1
.endmacro

;;
; Sets the (not battery-backed) work RAM size in bytes.
; Default is 0.
.macro nes2wram sz
.local logsz
  _nes2_logsize sz, logsz
  _nes2_wramsize = logsz
.endmacro

;;
; Sets the battery-backed work RAM size in bytes.  Default is 0.
.macro nes2bram sz
.local logsz
  _nes2_logsize sz, logsz
  _nes2_bramsize = logsz
.endmacro

;;
; Sets the (not battery-backed) CHR RAM size in bytes.  Default is 0
; if CHR ROM or battery-backed CHR RAM is defined; otherwise 8192.
.macro nes2chrram sz
.local logsz
  _nes2_logsize sz, logsz
  _nes2_chrramsize = logsz
.endmacro

;;
; Sets the battery-backed CHR RAM size in bytes.  Default is 0.
.macro nes2chrbram sz
.local logsz
  _nes2_logsize sz, logsz
  _nes2_chrbramsize = logsz
.endmacro

;;
; Sets the mirroring to one of these values:
; 'H' (horizontal mirroring, vertical arrangement)
; 'V' (vertical mirroring, horizontal arrangement)
; '4' (four-screen VRAM)
; 218 (four-screen and vertical bits on, primarily for mapper 218)
.macro nes2mirror mir
.local mi1
  mi1 = mir
  .if mi1 = 'h' .or mi1 = 'H'
    _nes2_mirror = 0
  .elseif mi1 = 'v' .or mi1 = 'V'
    _nes2_mirror = 1
  .elseif mi1 = '4'
    _nes2_mirror = 8
  .elseif mi1 = 218
    _nes2_mirror = 9
  .else
    .assert 0, error, "Mirroring mode must be 'H', 'V', or '4'"
  .endif
.endmacro

;;
; Sets the mapper (board class) ID.  For example, MMC3 is usually
; mapper 4, but TLSROM is 118 and TQROM is 119.  Some mappers have
; variants.
.macro nes2mapper mapperid, submapper
.local mi1, ms1
  mi1 = mapperid
  .assert mi1 >= 0 .and mi1 < 4096, error, "Mapper must be 0 to 4095"
  .ifnblank submapper
    .assert ms1 >= 0 .and ms1 < 16, error, "Submapper must be 0 to 15"
    ms1 = submapper
  .else
    ms1 = 0
  .endif
  _nes2_mapper6 = (mi1 & $0F) << 4
  _nes2_mapper7 = mi1 & $F0
  _nes2_mapper8 = (mi1 >> 8) | (ms1 << 4)
.endmacro

;;
; Sets the ROM's intended TV system:
; 'N' for NTSC NES/FC/PC10
; 'P' for PAL NES
; 'N','P' for dual compatible, preferring NTSC
; 'P','N' for dual compatible, preferring PAL NES
.macro nes2tv tvsystem, dual_compatible
.local tv1, tv2
  tv1 = tvsystem
  .ifnblank dual_compatible
    tv2 = $02
  .else
    tv2 = $00
  .endif
  .if tv1 = 'n' .or tv1 = 'N'
    _nes2_tvsystem = $00 | tv2
  .elseif tv1 = 'p' .or tv1 = 'P'
    _nes2_tvsystem = $01 | tv2
  .else
    .assert 0, error, "TV system must be 'N' or 'P'"
  .endif
.endmacro

;;
; Writes the header configured by previous nes2 macros.
.macro nes2end
.local battery_bit
  ; Apply defaults
  .ifndef _nes2_chrsize
    nes2chr 0
  .endif
  .ifndef _nes2_mirror
    nes2mirror 'H'
  .endif
  .ifndef _nes2_wramsize
    nes2wram 0
  .endif
  .ifndef _nes2_bramsize
    nes2bram 0
  .endif
  .ifndef _nes2_chrbramsize
    nes2chrbram 0
  .endif
  .ifndef _nes2_chrramsize
    .if _nes2_chrsize .or _nes2_chrsizehi .or _nes2_chrbramsize
      nes2chrram 0
    .else
      nes2chrram 8192
    .endif
  .endif
  .ifndef _nes2_tvsystem
    nes2tv 'N'
  .endif
  .if _nes2_bramsize .or _nes2_chrbramsize
    battery_bit = $02
  .else
    battery_bit = $00
  .endif

  .pushseg
  .segment "INESHDR"
  .byte "NES",$1A
  .byte _nes2_prgsize, _nes2_chrsize
  .byte _nes2_mapper6 | _nes2_mirror | battery_bit
  .byte _nes2_mapper7 | $08  ; not supporting vs/pc10 yet

  .byte _nes2_mapper8
  .byte (_nes2_chrsizehi << 4) | _nes2_prgsizehi
  .byte (_nes2_bramsize << 4) | _nes2_wramsize
  .byte (_nes2_chrbramsize << 4) | _nes2_chrramsize

  .byte _nes2_tvsystem, 0, 0, 0
  .popseg
.endmacro
