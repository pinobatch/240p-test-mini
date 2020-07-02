240p Test Suite
===============

The [240p Test Suite] is a homebrew software suite for video game
consoles developed to help in the evaluation of upscalers, upscan
converters and line doublers.

It has tests designed with the processing of 240p signals in mind,
although when possible it includes other video modes and specific
tests for them.  These have been tested with video processors on
real hardware and a variety of displays, including CRTs and Arcade
monitors via RGB.

As a secondary target, the suite aims to provide tools for
calibrating colors, black and white levels for specific console
outputs and setups. 

MDFourier is tool to compare audio signatures and generate graphs
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

Once the suite is running, the credits will appear.  You can navigate
the menu with the Control Pad and the A and B Buttons.  There are
two pages of tests, one with mostly still images and the other with
more interactive tests.  Each test is controlled with the Control Pad
and the A and Select Buttons.  To leave a test, press the B Button.

To show help for any test, press Start or read `src/helppages.txt`.
Gus, the character at left, was an esports instructor until game
publishers cracked down on the esports academies in June 2012 and
July 2013.  Then he became a home theater installer.

To skip straight to MDFourier tone generator, hold the Start Button
while turning on the power or while pressing the Reset Button.

Versions
--------
The Nintendo Entertainment System (NES) can output 240 picture
lines in a progressive "double struck" mode.  It does not support
interlaced video, and its 52-color palette is closer to HSV than RGB.
The three main regional variants (NTSC NES/Famicom, PAL NES, and PAL
famiclones) have different CPU speeds and frame rates.

The 240p test suite for Nintendo Entertainment System was developed
in 6502 assembly language using [ca65], with image conversion tools
written in Python 3 and [Pillow] (Python Imaging Library).  It
compensates for regional speed differences and has been tested on
authentic NTSC and PAL NES consoles and on a Dendy (PAL famiclone).

Artemio Urbina maintains the upstream suite on five platforms:

* It was first developed in C for the Sega Genesis using the SGDK,
  using 320x224p resolution.  It comes as a cartridge image or as
  a disc image for Sega CD.  Version 1.16 adds support for 256x224p.
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
* The author of the NES port also maintains a port to Game Boy and
  Game Boy Color and a port to Game Boy Advance.

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
* Portrait in Shadow sprite test: darryl.revok
* Hill zone background: mikejmoffitt
* Extra patterns and collaboration: Konsolkongen & [shmups] regulars
* "Crowd" bytebeat player: Kragen & rainwarrior

If you're interested in contributing to the NES port, you're invited
to post in its [development thread].  We seek experts with authentic
NES and clone consoles, both NTSC and PAL, who can run the suite on
high-quality displays and scalers.

[@Artemio]: https://twitter.com/Artemio
[@PinoBatch]: https://twitter.com/PinoBatch
[shmups]: http://shmups.system11.org/
[development thread]: http://forums.nesdev.com/viewtopic.php?t=13394

Copyright 2011-2018 Artemio Urbina  
Copyright 2015-2020 Damian Yerrick

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
