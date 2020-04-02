144p Test Suite
===============

The [240p Test Suite] is a homebrew software suite for video game
consoles developed to help in the evaluation of upscalers, upscan
converters and line doublers.

This program is a port of Artemio Urbina's 240p Test Suite
to the Game Boy, as a way of learning the Game Boy CPU.

Build requirements: RGBDS, Python 3, Pillow, and GNU Make

[240p Test Suite]: http://junkerhq.net/xrgb/index.php/240p_test_suite

Usage
-----
To run this on a Game Boy, load the ROM onto your [EverDrive-GB]
or [Catskull cartridge].

Once the suite is running, the credits will appear.  You can navigate
the menu with the Control Pad and the A and B Buttons.  There are
three pages of tests: one with mostly still images, one with more
interactive tests, and a third exclusive to Game Boy Color and
Super Game Boy that tests color balance.  Each test is controlled
with the Control Pad and the A and Select Buttons.  To show help for
any test, press Start or read src/helppages.txt. To leave a test,
press the B Button.

[EverDrive-GB]: https://krikzz.com/store/home/48-everdrive-gb.html
[Catskull cartridge]: https://catskullelectronics.com/32kcart

Versions
--------
The Game Boy outputs a progressive video signal with 144 lines
of picture.  The original Game Boy and Game Boy Pocket have a
passive matrix STN LCD panel that displays four shades of gray.
The Super Game Boy accessory maps these gray shades to colors.
The Game Boy Color has a TFT panel with 32 levels per RGB channel.
Super Game Boy and Game Boy Player accessories act as scalers to
allow use of Game Boy software with a television.

The Game Boy display works by absorbing light instead of emitting it.
Because of this "subtractive" nature, as well as the overall reduced
contrast and other display artifacts on monochrome handhelds, many
tests allow inverting grays with the Select Button.

To keep positive and negative voltages balanced, an LCD inverts each
pixel's phase on alternate frames.  Game Boy displays alternate this
phase by row.  Thus slight level differences between a pixel and its
inverted counterpart can look like interlace.
(See "[LCD monitor technology and tests]" by W. Andrew Steer.)

[LCD monitor technology and tests]: http://www.techmind.org/lcd/

Though the NES version of 240p Test Suite uses about 40 KiB of ROM
data, the [Catskull cartridge] is limited to 32 KiB.  Fortunately,
the graphics for several tests are smaller than on a 240p platform,
which makes the menu, Linearity, Sharpness, Drop Shadow, and Scroll
Test smaller.  I managed to make some tests' help text more concise.
Easily readable VRAM helps, as does the 8080 family's better code
density for anything that doesn't use structs or parallel arrays.

A Game Boy Advance port is also available.

Artemio Urbina maintains the upstream suite on five platforms:

* Sega Genesis (Mega Drive), as cartridge and Sega CD
* TurboGrafx-16 (PC Engine), as HuCard, CD-ROM2, and Super CD-ROM2
* Super NES (Super Famicom), as cartridge
* Sega Dreamcast, as MIL-CD
* Nintendo GameCube and Wii, as GameCube disc and DOLs for SD loader

The name
--------
NTSC analog televisions were designed for interlaced video conforming
to CCIR [System M and System J], which specify an analog video
signal with 15.734 kHz by 59.94 Hz sync frequencies and 480 out of
525 lines.  Most video game consoles before the Dreamcast bent the
rules, producing progressive video with 240 out of 262 or 263 lines.
This was out of spec yet within TVs' tolerances.  This sort of signal
came to be called "240p" video.

Some handhelds drive their internal LCD with System M-like timings.
For example, the Game Gear's display has 144 active lines, which
are centered in the 240p output of EvilTim's [Game Gear RGB] mod.
The Game Boy, on the other hand, uses an incompatibly slower 9.2 kHz
horizontal sync.  Super Game Boy has to use a frame buffer to
convert the timing to 240p or 480i, which adds lag.  This is why
the Game Boy port is renamed.

[System M and System J]: https://en.wikipedia.org/wiki/CCIR_System_M
[Game Gear RGB]: http://members.optusnet.com.au/eviltim/ggrgb/ggrgb.html

Limits
------
* Linearity: No support for non-square NTSC or PAL pixel aspect
  ratios when used through Super Game Boy.
* Gradient and SMPTE color bars are not available on SGB.
* Sound Test: No "Crowd" because GB PCM is limited to 4 bits.
* Alternate 240p/480i: SGB and GB Player offer no control over
  the host systems' interlace modes except through SGB JUMP.
* The IRE levels of the Super NES and Nintendo GameCube video output
  have not yet been measured.

Contributors
------------
* Concept: Artemio Urbina [@Artemio]
* Code: Damian Yerrick [@PinoBatch]
* Main menu graphics: Damian Yerrick
* Portrait in Shadow sprite test: darryl.revok
* Hill zone background: mikejmoffitt
* Extra patterns and collaboration: Konsolkongen & [shmups] regulars

If you're interested in contributing to the Game Boy port, you're
invited to post in its [NESdev thread] or [GBDev thread].

[@Artemio]: https://twitter.com/Artemio
[@PinoBatch]: https://twitter.com/PinoBatch
[shmups]: http://shmups.system11.org/
[NESdev thread]: https://forums.nesdev.com/viewtopic.php?f=20&t=17221
[GBDev thread]: http://gbdev.gg8.se/forums/viewtopic.php?id=542

Copyright 2011-2018 Artemio Urbina  
Copyright 2018-2019 Damian Yerrick

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
