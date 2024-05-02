 Test sequences
==============

Mapper detection
----------------
All licensed games on MMC5, VRC6, Namco 163, and Sunsoft 5B use PRG
ROM and CHR ROM.  The only licensed game on VRC7 uses PRG ROM and CHR
RAM.  All licensed disk games are on a disk.  This means this project
will need to ship at least three artifacts: a ROM with PRG ROM and
CHR ROM, a ROM with PRG ROM only, and a disk image.

As with [Holy Mapperel], I'll distinguish the four mappers used in
Famicom cassettes with CHR ROM and expansion audio through their
nametable mirroring behavior.  Then after selecting a background,
a 2-minute test pattern will begin.

[Holy Mapperel]: https://github.com/pinobatch/holy-mapperel

VRC6
----
Implementation pending

1. Sync pulses (20 frames silence, 10 loops of 1 frame 8 kHz V07
   pulse and 1 frame silence, 20 frames silence)
2. 36-note pentatonic scales (C, D#, F, G, A#), beginning at lowest
   C (32.7 Hz) and ascending to C 7 octaves up (4186 Hz) at 10 frames
   per note, followed by 20 frames silence.  Repeat for pulse V00
   through V07 and saw at volumes 30 and 62.
3. 60 frames silence
4. G (392 Hz) for 20 frames with channel off/on every frame, then
   10 frame silence.  Demonstrates how to reset phase
5. G then pitch bending up 2 period units per frame for 20 frames,
   then 10 frame silence.  Demonstrates that period high write
   doesn't itself reset phase
6. V00 pulse slide from A (440 Hz) up at 1 period unit per frame
   for 270 frames, then 10 frames silence.  Tests aliasing and
   ultrasound response
7. Likewise with volume 62 saw from B (494 Hz).
8. Fades at 5 frames per unit followed by 15 frames silence using
   square waves.  VRC6 pulse 1 plays 1 kHz fading out five times,
   while VRC6 pulse 2 plays nothing, 500 Hz fading out, 1 kHz fading
   out, 500 Hz fading in, and 1 kHz fading in.  Repeat with 2A03
   pulse 1 instead of VRC6 pulse 1.
9. Fades at 5 frames per unit followed by 15 frames silence using
   1/8 pulse.  VRC6 out, 2A03 out, 2A03 out + VRC6 out,
   2A03 out + VRC6 in
10. Saw fade from 63 to 1 at 2 frames per step (total 126 frames),
    24 frames silence, from 8 to 0 at 10 frames per step, 10 frames
    silence.  Tests transition at wraparound and LSB loss.
11. For $4011 in $00, $0F, $1F, $2F, $3F, $4F, $5F, $6F, $7F, $0F:
    10 frames silence, 20 frames 1 kHz pulse, 20 frames 1 kHz saw,
    10 frames silence
12. Repeat sync pulses

VRC7
----
Pending

YM2149
------
Pending.  Will need to touch square, noise, envelope, and
combinations thereof.  Be aware that as with DCSG (mdfourier-sms),
YM2149 square has no wave position reset.

MMC5
----
Design pending.  Intended to resemble VRC6.  Some sort of PCM
response is needed.

Namco 129/163
-------------
Pending.  If there's a PC Engine tone generator, I might take
inspiration from that.

Disk System
-----------
1. Sync pulses (20 frames silence, 10 loops of 1 frame 1 kHz 8x
   square wave and 1 frame silence, 20 frames silence)
2. 94-note chromatic scale, beginning at lowest
   C (8.11 Hz) and ascending to out-of-tune A 7 octaves up
   (1747.40 Hz) at 10 frames per note, followed by 10 frames silence.
   Repeat for waveforms sine, square, and 32x square at volume 32.
   TODO: increase silence before next test
3. Three DC offset pops for 20 frames, first with wave value $3F,
   then $00, both at volume 32, phase resetted, and waveform halted.
   Third DC pop silences second DC pop, testing for DC offset.
   10 frames silence
   TODO: halt waveform instead of setting to highest period
4. A (440 Hz) for 20 frames, halting and then resuming waveform
   playback. Halting the waveform resets the phase.
   Then, 10 frames silence
5. Pitch Slide from C (8.11 Hz) up at 8 period unit per frame
   for 560 frames, then 10 frames silence. Repeat for sine, square,
   sawtooth, and 32x square. 32x square tests aliasing and ultrasound
   response, while the rest tests for general frequency response.
   TODO: shorten length and add silence
6. db_fds, from rainwarrior's nes-audio-tests.
   Loudest FDS square at A (439.94 Hz) for two seconds (12 frames).
   Then 1 second of silence (6 frames).
   Then loudest 2A03 pulse square at A (440.40 Hz) for two seconds (12
   frames).
   Then 1 second of silence (6 frames).
7. Relative phase test. Sawtooth wave note at C (65.29 hz) for 30
   frames. 10 frames silence.
   2A03 25% pulse note at C (65.42 Hz) for 30 frames.
   10 frames silence.
8. Nonlinear FDS DAC test. "Sorted" sawtooth wave note at C (65.29 hz)
   for 30 frames. 10 frames silence.
9. Master volume test. 4 sawtooth wave notes of 109.24 Hz (period
   $100) for 30 frames. 10 frames silence.
   Each note decreasing in master volume (00, 01, 10, 11).
10. Envelope test.
    3 sawtooth wave notes of C (523.15 hz) and one DC offset envelope
    for 40 frames with different methods of modifying volume.
    1. manual volume gain write, decreasing volume gain every frame
    2. hardware volume sweep decrease, speed chosen to closely match
       video framerate ($32 speed, $48 master envelope speed)
    3. hardware volume sweep increase, speed chosen to closely match
       video framerate ($32 speed, $48 master envelope speed)
    4. DC manual volume gain write, decreasing volume gain every frame.
    TODO: measure exact envelope length by writing to $4080 and
    counting cycles
11. Modulator test.
    TODO: mod envelope tests
    TODO: mod overflow/underflow tests
    6 notes of C (261.58 Hz) for 40 frames, each with varying
    modulator and modulator table properties.
    a. sine wave, FT "NEZPlug" mod sine, mod depth of $3F, mod period
       of $265. This checks for mod table index sync.
    b. sine wave, Dn-FT mod sine, mod depth of $3F, mod period
       of $265. This compares against previous wave.
    c. sine wave, modtable_data_mod_reset, mod depth of $10, mod
       period of $020. This checks for mod counter reset.
    d. sine wave, modtable_data_mod_overflow, mod depth of $10, mod
       period of $020
    e. sine wave, modtable_data_mod_underflow, mod depth of $10, mod
       period of $020
    f. sine wave, FT "NEZPlug" mod sine, mod depth of $3F, mod period
       of $265. In addition to $4085=$20, this will test for $4087.7
       latch delay.
12. Modulator envelope test.
    3 sawtooth wave notes of C (523.15 hz) for 40 frames with
    different methods of modifying modulator gain.
    1. manual mod gain write, decreasing mod gain every frame
    2. hardware mod sweep decrease, speed chosen to closely match
       video framerate ($32 speed, $48 master envelope speed)
    3. hardware mod sweep increase, speed chosen to closely match
       video framerate ($32 speed, $48 master envelope speed)
    (value $0A to $4080).
    Each note decreases master volume (00, 01, 10, 11).
    TODO: measure exact envelope length by writing to $4080 and
    counting cycles
13. Repeat sync pulses

to find out:
- [ ] is the wave and mod unit ticked on the same M2 cycle?
- [ ] is it possible to determine wave unit M2 alignment?
- [ ] is it possible to determine mod unit M2 alignment?
- [ ] is it feasible to align test start with wave/mod unit?
- [ ] does mod unit envelopes also wait for wavepos==0 latch (like wave unit envelopes)?