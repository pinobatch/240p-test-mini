240p Test Suite
===============

Most video game consoles prior to 1999 output a 240-line progressive
(240p) video signal.  Though it has nonstandard timing compared to
broadcast TV, most TVs from the 1980s can display it.  However, many
flat-panel TVs from 2007 and later have trouble with 240p video.

The [240p Test Suite] is a homebrew application for video game
consoles that helps evaluate compatibility of upscalers and other
video processors, either stand-alone or built into a TV, with retro
consoles' video.  It also provides tools for calibrating black and
white levels, colors, and picture size for accurate reproduction
across displays.  These have been tested with video processors on
real hardware and a variety of displays, including CRTs and arcade
monitors via RGB.

MDFourier is a tool to compare audio signatures and generate graphs
that show how they differ.  A tone generator produces a signal for
recording from the console, and the analysis program compares the
frequencies to a reference recording and displays the results.

This is free software, with full source code available under the GPL.

[240p Test Suite]: http://junkerhq.net/xrgb/index.php/240p_test_suite

Usage
-----
Load 240pee.nes onto a [PowerPak] or [EverDrive-N8] and run it.

You can also burn it to an NES cartridge with an UNROM board.
Full instructions are in `making-carts.md`.

In menus and help:

* Control Pad ⬅➡: Turn page
* Control Pad ⬆⬇: Move cursor
* A Button: Choose option
* B Button: Go to previous menu
* Start Button: Show help for menu

In an activity:

* Control Pad, A, Select: Control activity
* Start Button: Show help for activity
* B Button: Close activity

To show help for any test, press Start or read `src/helppages.txt`.
Gus, the character at left, was an esports instructor until game
publishers cracked down on the esports academies in June 2012 and
July 2013.  Then he became a home theater installer.

To skip straight to MDFourier tone generator, hold the Start Button
while turning on the power or while pressing the Reset Button.

Versions
--------
The Nintendo Entertainment System outputs 240 picture lines in a
progressive "double struck" mode.  It does not support interlaced
video, and its 52-color palette is closer to HSV than RGB.

The 240p Test Suite for NES was developed in 6502 assembly language
using [ca65], with image conversion tools written in Python 3 and
[Pillow] (Python Imaging Library).  It compensates for the different
CPU speeds and frame rates among the console's regional variants
and has been tested on authentic NTSC and PAL NES consoles and on a
Dendy (PAL famiclone).

The stand-alone MDFourier ROMs boot straight into the tone generator.
The autostart version lacks the buzzing side effect from controller
reading and may be easier to use with a disassembled console or an
emulator's automated test harness.

Artemio Urbina maintains the upstream suite on five platforms:

* It was first developed in C for the Sega Genesis using the SGDK,
  using 320x224p or 256x224p resolution.  It comes as a cartridge
  image or as a disc image for Sega CD.
* The TurboGrafx-16 version was made with HuC.  It supports widths
  256, 320, and 512, and heights 224 and 239.  It comes as a HuCard
  image for Turbo EverDrive, a disc image for CD-ROM2 (TurboGrafx-CD
  with System Card 1/2), and a disc image for Super CD-ROM2
  (TurboDuo or Super System Card) that loads completely into RAM.
* The Super NES version was coded using PVSnesLib.  It runs mostly
  in 256x224p, with a few tests in the less common 256x239p mode.
* The Sega Dreamcast version was made with KallistiOS and runs on
  any MIL-CD compatible Dreamcast console.  It supports 240i, 480i,
  480p, 288p, and 576i resolutions, cables and crystals permitting.
  It supports a microphone peripheral for audio lag testing.
* The Nintendo GameCube version was made with devkitPPC and runs on
  any homebrew-capable GameCube or Wii console.  It supports the same
  resolutions as the Dreamcast version.  It comes as a disc image for
  a modded GameCube, a DOL file for SD Media Launcher on GameCube,
  and a DOL file for Homebrew Channel on Wii.

The author of the NES port also maintains a port to Game Boy,
which is enhanced for Super Game Boy and Game Boy Color,
and a port to Game Boy Advance.

[ca65]: https://cc65.github.io/cc65/
[Pillow]: https://pillow.readthedocs.org/
[PowerPak]: http://www.retrousb.com/product_info.php?cPath=24&products_id=34
[EverDrive-N8]: http://www.stoneagegamer.com/everdrive-n8-deluxe-nes.html

Limits
------
It was discovered in January 2017 that the Famicom's microphone is
not sensitive enough to detect the TV's audio.  Because the console
mixes the mic's signal directly into the audio mix, the mic's volume
control affects both the sensitivity of the comparator and the level
of the output from the TV.  And if the mic is turned up high enough,
a feedback whine can be heard.  So the automatic audio lag detection
must remain exclusive to the Dreamcast.

The phase of the triangle channel affects the volumes of the noise
and DPCM channels in the MDFourier tone generator.  Playing a note
on the triangle channel alters this phase, possibly rendering
MDFourier analysis results invalid.  This includes the Select button
in SMPTE color bars and Color bars on gray, as well as most options
in Sound test.  If the triangle phase has been trashed, MDFourier
will instruct you to press the Reset Button on the Control Deck.

Contributors
------------
* Concept: Artemio Urbina [@Artemio]
* Code: Damian Yerrick [@PinoBatch]
* Main menu graphics: Damian Yerrick
* Portrait of Gus in Shadow sprite test: darryl.revok
* Hill zone background: mikejmoffitt
* [Monoscope pattern]: Keith Raney
* Extra patterns and collaboration: Konsolkongen & [shmups] regulars
* "Crowd" bytebeat player: Kragen & rainwarrior

If you're interested in contributing to the NES port, you're invited
to post in its [development thread].  We seek experts with authentic
NES and clone consoles, both NTSC and PAL, who can run the suite on
high-quality displays and scalers.

[@Artemio]: https://twitter.com/Artemio
[@PinoBatch]: https://twitter.com/PinoBatch
[Monoscope pattern]: https://www.retrorgb.com/240p-test-suite-monoscope-test-pattern-added.html
[shmups]: http://shmups.system11.org/
[development thread]: http://forums.nesdev.com/viewtopic.php?t=13394

Copyright 2011-2018 Artemio Urbina  
Copyright 2015-2021 Damian Yerrick

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
