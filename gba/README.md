160p Test Suite
===============

The [240p Test Suite] is a homebrew software suite for video game
consoles developed to help in the evaluation of upscalers, upscan
converters and line doublers.

This program is a port of Artemio Urbina's 240p Test Suite
to the Game Boy Advance.

[240p Test Suite]: http://junkerhq.net/xrgb/index.php/240p_test_suite

Usage
-----
This is a multiboot program, one that runs entirely in RAM.  It can
be loaded onto a GBA through a flash card, a GBA Movie Player, a PC
with an MBV2 or Xboo multiboot cable, or the homebrew Game Boy
Interface software for GameCube.

Once the suite is running, the credits will appear.  You can navigate
the menu with the Control Pad and the A and B Buttons.  There are
two pages of tests: one with mostly still images and one with more
interactive tests.  Each test is controlled with the Control Pad and
the A and Select Buttons.  To show help for any test, press Start or
read src/helppages.txt. To leave a test, press the B Button.

Because the controls match the Game Boy Color version, the L and R
(shoulder) buttons are not used.

Versions
--------
The Game Boy Advance system outputs progressive video with 160
lines of picture.  Its TFT panel has 32 levels per RGB channel
and a reputation for crushing black levels, for which its launch
titles failed to compensate.  Game Boy Advance SP and Nintendo DS
are backlit.

The Game Boy Player accessory for Nintendo GameCube outputs 480i
or 480p video.  It acts as a scaler to allow use of GBA software
with a television.

The GBA display works by absorbing light instead of emitting it.
Because of this "subtractive" nature, as well as the overall
darkness on GBA prior to SP, many tests allow inverting grays
with the Select Button.

NES and Game Boy ports are also available.

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
The GBA, on the other hand, uses an incompatibly slower 13.6 kHz
horizontal sync.  Game Boy Player has to use a frame buffer to
convert the timing to 240p or 480i, which adds lag.  This is why
the GBA port is renamed.

[System M and System J]: https://en.wikipedia.org/wiki/CCIR_System_M
[Game Gear RGB]: http://members.optusnet.com.au/eviltim/ggrgb/ggrgb.html

Limits
------
* Alternate 240p/480i is omitted because Game Boy Player offers
  no control over the host system's interlace mode.  GBI users
  can use the native GameCube suite instead.
* The true IRE levels of the GameCube's output when running Game Boy
  Player have not yet been measured.

Building
--------
Build requirements: GNU Coreutils and Make (use devkitPro MSYS on
Windows), devkitARM, libgba, Python 3, and Pillow.

Under Windows, open a devkitPro MSYS and type `make`.  Under Linux
or macOS, once you have installed `gba-dev` using pacman, type these:

    source /etc/profile.d/devkit-env.sh
    make

Contributors
------------
* Concept: Artemio Urbina [@Artemio]
* Code: Damian Yerrick [@PinoBatch]
* Main menu graphics: Damian Yerrick
* Portrait in Shadow sprite test: darryl.revok
* Hill zone background: mikejmoffitt
* Extra patterns and collaboration: Konsolkongen & [shmups] regulars

If you're interested in contributing to the GBA port, you're
invited to post in its [gbadev thread].

[@Artemio]: https://twitter.com/Artemio
[@PinoBatch]: https://twitter.com/PinoBatch
[shmups]: http://shmups.system11.org/
[gbadev thread]: http://forum.gbadev.org/viewtopic.php?t=18168

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
