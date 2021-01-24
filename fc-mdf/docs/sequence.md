Test sequences
==============

Mapper detection
----------------
As with [Holy Mapperel], I'll distinguish the five mappers used in
Famicom cassettes with expansion audio through their nametable
mirroring behavior.  Then after selecting a background, a 2-minute
test pattern will begin.

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
   for ? frames, then ? frames silence.  Tests aliasing and
   ultrasound response
7. Likewise with volume 62 saw from B (494 Hz).
8. Fades at 5 frames per unit followed by 15 frames silence.
   VRC6 pulse 1 plays 1 kHz fading out five times, while VRC6 pulse 2
   plays nothing, 500 Hz fading out, 1 kHz fading out, 500 Hz fading
   in, and 1 kHz fading in.  Repeat with 2A03 pulse 1 instead of
   VRC6 pulse 1.
9. Fades involving saw, to be characterized
10. For $4011 in $00, $0F, $1F, $2F, $3F, $4F, $5F, $6F, $7F, $0F:
    10 frames silence, 20 frames 1 kHz pulse, 20 frames 1 kHz saw,
    10 frames silence
11. Repeat sync pulses

VRC7
----
Pending

YM2149
------
Pending.  Will need to touch square, noise, and combinations thereof.

MMC5
----
Design pending.  Intended to resemble VRC6.  Some sort of PCM
response is needed.

Disk System
-----------
Pending

Namco 129/163
-------------
Pending
