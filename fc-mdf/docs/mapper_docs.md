Concise mapper docs
===================

For writing MDFourier code on a laptop away from the Internet, such
as in the grocery store parking lot.

VRC6
----
iNES mapper: 24; NSF bitmask: $01

This describes the subset of VRC6 used in licensed games by Konami.
For full details, see NESdev Wiki.  This describes the "normal"
mapping (#24); some games swap A0 and A1 (#26) which exchanges
the sense of addresses ending in 1 or 2.

- $8000: Select 16K PRG bank at $8000
- $9000: Pulse 1 duty (bits 6-4) and volume (bits 3-0)
- $9001: Pulse 1 period low
- $9002: Pulse 1 enable (bit 7) and period high (bits 3-0)
- $9003: Frequency scale (0: run; 1: pause oscillators) [Subset]
- $A000: Pulse 2 duty and volume
- $A001: Pulse 2 period low
- $A002: Pulse 2 enable and period high
- $B000: Saw volume (0-42: normal; 43-63: double peak)
- $B001: Saw period low
- $B002: Saw enable and period high
- $B003: WRAM enable (bit 7) and nametable mirroring mode (bits 3-2)
- $C000: Select 8K PRG bank at $C000
- $D000-$D003: Select 1K CHR bank at $0000, $0400, $0800, $0C00
- $E000-$E003: Select 1K CHR bank at $1000, $1400, $1800, $1C00
- $F000: IRQ latch reload value (up counter)
- $F001: IRQ control (bitfield; see below)
- $F002: Acknowledge IRQ

VRC6 bitfields:

    7654 3210  $9000, $A000: Pulse duty and volume
    |||| ++++- Volume
    ++++------ Pulse width (0-7: 1/16 to 8/16; 8-F: 100%)
    
    7654 3210  $F001: IRQ control
          ||+- 1: Keep IRQ enabled after write to acknowledge
          |+-- 1: Enable IRQ and reset 
          +--- 0: count 114,114,113-cycle scanlines; 1: count cycles

These numbers indicate nametable mirroring modes on VRC6, VRC7,
and FME-7:

- 0: ABAB, horizontal arrangement, vertical mirroring
- 1: AABB, vertical arrangement, horizontal mirroring
- 2: 1-screen A
- 3: 1-screen B

MMC1 and Action 53 use the same codes with bit 1 inverted.

VRC7
----
iNES mapper: 85; NSF bitmask: $02

_Lagrange Point_ uses this mapper, which contains a cut-down
version of the Yamaha YM2413 OPLL with no rhythm section (thus
6 channels) and preset patches replaced with ports of the
instruments of _Space Manbow_.

- $8000: Select 8K PRG bank at $8000
- $8010: Select 8K PRG bank at $A000
- $9000: Select 8K PRG bank at $C000
- $9010: Audio address (wait 6 cycles afterward)
- $9030: Audio data (wait 42 cycles afterward)
- $A000, $A010: Select 1K PRG bank at $0000, $0400
- $B000, $B010: Select 1K PRG bank at $0800, $0C00
- $C000, $C010: Select 1K PRG bank at $1000, $1400
- $D000, $D010: Select 1K PRG bank at $1800, $1C00
- $E000: WRAM enable (bit 7), reset OPLL (bit 6), mirroring (bits 1-0)
- $E010: IRQ latch (like VRC6)
- $F000: IRQ control (like VRC6)
- $F010: IRQ acknowledge (like VRC6)

OPLL functions

- $00: Modulator tremolo, vibrato, sustain, key rate scaling, multiplier
- $01: Carrier tremolo, vibrato, sustain, key rate scaling, multiplier
- $02: Modulator key level scaling, output level
- $03: Carrier key level scaling, carrier and modulator waveforms, feedback
- $04: Modulator attack rate (bits 7-4) and decay rate (bits 3-0)
- $05: Carrier attack rate and decay rate
- $06: Modulator sustain level (bits 7-4) and release rate (bits 3-0)
- $07: Carrier sustain and release
- $0F: Max envelope amount (bit 0), reset LFO (bit 1), reset waveform phase (bit 2), faster vibrato and tremolo (bit 3)
- $10-$15: Low 8 bits of frequency for channels 1-6
- $20-$25: Force release rate=5 (bit 5), note on/off (bit 4), octave (bits 3-1), frequency high (bit 0)
- $30-$35: Instrument (bits 7-4)

Famicom Disk System
-------------------
Disk image format: .fds; NSF bitmask: $04

Single-channel wavetable chip roughly equivalent to Konami SCC.
To be described.

MMC5
----
iNES mapper: 5; NSF bitmask: $08

MMC5 is a very big mapper.  I'll describe a simplified
interface based on what most licensed games use.

- $2000: If bit 5 (OBJ_8X16) is 0, disable 8x16 CHR bank
- $2001: If bits 4-3 (rendering enable) are 0, disable 8x16 CHR bank
- $5000: Pulse 1 duty and volume [Bitfield]
- $5002: Pulse 1 period low
- $5003: Pulse 1 period high; writes reset wave position
- $5004: Pulse 2 duty and volume [Bitfield]
- $5006: Pulse 2 period low
- $5007: Pulse 2 period high; writes reset wave position
- $5010: Enable IRQ when DAC becomes 0 (bit 7); update on $8000-$BFFF
  read instead of write (bit 0)
- $5011: DAC value
- $5015: Pulse 1 enable (bit 0); pulse 2 enable (bit 1)
- $5100: Bank mode (3: 8Kx4; only _Castlevania III_ differs)
- $5101: CHR mode (3: 1Kx8; only _Metal Slader Glory_ differs)
- $5104: ExRAM mapping (2: Use as work RAM, not ExGrafix)
- $5105: Mirroring ($00: A; $44: vertical; $50: horizontal; $55: B)
- $5114: Select 8K PRG bank at  ($80-$FF: ROM)
- $5115: Select 8K PRG bank at $A000 ($80-$FF: ROM)
- $5116: Select 8K PRG bank at $C000 ($80-$FF: ROM)
- $5117: Select 8K PRG bank at $E000
- $5120-$5127: Select 1K CHR bank at $0000, $0400, ...., $1C00
- $5128-$512B: Select 1K CHR bank at $0000, $0400, $0800, $0C00
  for use in background while 8x16 sprites are enabled
- $5200: ExRAM vertical split screen (0: disable)
- $5203: LYC (Scanline on which to set IRQ pending)
- $5204: STAT [Bitfield]
- $5205: [Write] Multiplier factor 1; [Read] Product low
- $5206: [Write] Multiplier factor 2; [Read] Product high
- $5C00-$5FFF: ExRAM

At power on, $5100=$03, $5117=$FF, $5010=$01, $5015: $00

MMC5 bitfields:

    7654 3210  $4000, $4004, $5000, $5004: 2A03/MMC5 duty and volume
    |||| ++++- Volume
    ||++------ 3: Disable hardware fade and length counter
    ++-------- Pulse width (0: 1/8; 1: 1/4; 2: 1/2; 3: 3/4)
    
    7654 3210  $5204 Scanline timer status
    |+-------- [Read] 0: PPU is in vblank; 1: PPU is rendering
    +--------- [Write] 1: Enable IRQ
               [Read] 1: IRQ is pending; cleared on read

The DAC is much more linear than that of 2A03 $4011.

Namco 163
---------
iNES mapper: 19; NSF bitmask: $10

Multi-channel wavetable chip roughly equivalent to Konami SCC.

- $4800: ARAM data
- $5000: IRQ counter low
- $5800: IRQ enable (bit 7); IRQ counter high (bits 6-0)
- $8000: Select 1K CHR bank at $0000
- $8800: Select 1K CHR bank at $0400
- $9000: Select 1K CHR bank at $0800
- $9800: Select 1K CHR bank at $0C00
- $A000: Select 1K CHR bank at $1000
- $A800: Select 1K CHR bank at $1400
- $B000: Select 1K CHR bank at $1800
- $B800: Select 1K CHR bank at $1C00
- $C000: Select 1K CHR bank at $2000 (>=$E0: CIRAM)
- $C800: Select 1K CHR bank at $2400 (>=$E0: CIRAM)
- $D000: Select 1K CHR bank at $2800 (>=$E0: CIRAM)
- $D800: Select 1K CHR bank at $2C00 (>=$E0: CIRAM)
- $E000: Mute sound (bit 6); select 8K PRG ROM at $8000 (bits 5-0)
- $E800: PRG select $A000 [Bitfield]
- $F000: Select 8K PRG ROM at $C000
- $F800: ARAM address and WRAM enable

Audio RAM:

- $40-$47: Channel 1
- $48-$4F: Channel 2
- $50-$57: Channel 3
- $58-$5F: Channel 4
- $60-$67: Channel 5
- $68-$6F: Channel 6
- $70-$77: Channel 7
- $78-$7F: Channel 8
- $7F bits 6-4: Enable channels 8-x through 8 (total x+1 channels)

The sample period is M2/15 (119318 Hz) divided by the number
of enabled channels ($7F bits 6-4 plus 1).  Because the DAC
is multiplexed, it produces a whine at the sample period.
A cartridge may contain a low-pass filter to reduce this whine.

Each channel has an 8-byte control block

- 0: Frequency low (unit: 1/65536 sample per period)
- 1: Phase low
- 2: Frequency mid (unit: 1/256 sample per period)
- 3: Phase mid
- 4: Frequency high and length [Bitfield]
- 5: Phase high (current address)
- 6: Starting address (4-bit samples)
- 7: Channel count (bits 6-4, channel 7 only); volume (bits 3-0)

Bitfields:

    7654 3210  N163 $E800: PRG select $A000
    ||++-++++- Select 8K PRG ROM at $A000
    |+-------- CHR banks >=$E0 at $0000-$0FFF are 0: CIRAM; 1: ROM
    +--------- CHR banks >=$E0 at $1000-$1FFF are 0: CIRAM; 1: ROM
    
    7654 3210  N163 $F800: ARAM address and WRAM enable
    |+++-++++- Set address in ARAM to read or write at $4800
    +|||-||||- 1: After $4800 read or write, add 1 to address
    ||||-|||+- 0: Enable; 1: disable WRAM at $6000-$67FF
    ||||-||+-- 0: Enable; 1: disable WRAM at $6800-$6FFF
    ||||-|+--- 0: Enable; 1: disable WRAM at $7000-$77FF
    ||||-+---- 0: Enable; 1: disable WRAM at $7800-$7FFF
    ++++------ 4: enable if above set; other: disable all WRAM
    
    7654 3210  N163 ARAM channel byte 4: Frequency high and length
    |||| ||++- Frequency high (unit: 1 sample per period)
    ++++-++--- Length in samples (256 - 4*x)

Like the 2A03, the MMC5 ticks the pulses' period counter every second
M2 cycle.

Sunsoft 5B
----------
iNES mapper: 69; NSF bitmask: $20

This chip contains an FME-7 mapper and Yamaha YM2149 SSG audio.

- $8000: FME-7 address
- $A000: FME-7 data
- $C000: SSG address
- $E000: SSG data

FME-7 functions

- $00-$07: Select 1K CHR bank at $0000, $0400, ...., $1C00
- $08-$0B: Select 8K PRG bank at $6000, $8000, $A000, $C000
- $0C: Mirroring
- $0D: IRQ count (bit 7) and enable (bit 0); writes acknowledge
- $0E: IRQ counter low
- $0F: IRQ counter high

SSG functions

- $00: Square 1 period low
- $01: Square 1 period high
- $02: Square 2 period low
- $03: Square 2 period high
- $04: Square 3 period low
- $05: Square 3 period high
- $06: Noise period
- $07: Noise/tone enable [Bitfield]
- $08: Channel 1 volume (0-15: literal; 16: envelope controlled)
- $09: Channel 2 volume (0-15: literal; 16: envelope controlled)
- $0A: Channel 3 volume (0-15: literal; 16: envelope controlled)
- $0B: Envelope low period
- $0C: Envelope high period
- $0D: Envelope shape

SSG bitfields

    7654 3210
      || |||+- 0: Play square 1 through channel 1
      || ||+-- 0: Play square 2 through channel 2
      || |+--- 0: Play square 3 through channel 3
      || +---- 0: Play noise through channel 1
      |+------ 0: Play noise through channel 2
      +------- 0: Play noise through channel 3

Envelope shapes

    00-03, 09  \_______  Single down ramp
    04-07, 0D  /¯¯¯¯¯¯¯  Single up ramp
    08         \\\\\\\\  Downward saw
    0A         \/\/\/\/  Downward triangle
    0B         \¯¯¯¯¯¯¯  Single down ramp, then high
    0C         ////////  Upward saw
    0E         /\/\/\/\  Upward triangle
    0F         /_______  Single up ramp, then low

SSG ticks the pulse and envelope period counters every 16 cycles
and the noise period counter every 32.  The square waves have two
wave positions (1 and 0) and the envelope 32 to 64.  For this
reason, an envelope saw plays four octaves below a square with the
same period, and an envelope triangle one octave lower than that.
This makes the envelope out of tune for anything but bass.

Unlike 2A03, MMC5, and VRC6 period, SSG period does not add 1
to the period value: $FF means 255 cycles, not 256.  There is no
defined way to reset the square and noise wave position.

Each of the three channels has a logarithmic DAC with 31 steps from
0 or 1 (silent) to 2 (quiet) to 31 (loud), where each step starting
at 0.5 is 1.5 dB louder than the one below.  Literal volumes output
only odd values, whereas envelope can output all values.  When square
and/or noise is enabled on a channel, and the corresponding square or
noise generator is outputting 0, the DAC outputs 0 instead of the
literal or envelope value.

Detection procedure
-------------------
As with [Holy Mapperel], I'll distinguish the mappers through their
nametable mirroring behavior.  The following is preliminary:

1. Probe CIRAM after $5105=$01
   If L-shaped then **MMC5**
2. Set $8000=$0C.
   Probe CIRAM after $A000=$00-$03.
   If V, H, A, B then **FME-7** and possibly a YM2149
3. Probe CIRAM after $E000=$00-$03.
   If V, H, A, B then **VRC7**
3. Probe CIRAM after $B003=$00, $04, $08, $0C.
   If V, H, A, B then **VRC6**, after which distinguish AD from ED2.
4. Probe CIRAM with $C000=$FE, $C800=$D000=$D800=$FF.
   If L-shaped then **N163**

[Holy Mapperel]: https://github.com/pinobatch/holy-mapperel
