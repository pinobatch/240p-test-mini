144p Test Suite
===============
This ROM is a port of Artemio Urbina's 240p Test Suite to the
Game Boy, as a way of learning the Game Boy CPU.

Build requirements: RGBDS, Python 3, Pillow, and GNU Make

Usage instructions
------------------
Each test is controlled with the Control Pad and the A and
Select buttons.  To show help for any test, press Start or
read src/helppages.txt. To leave a test, press the B button.

Comparison with other ports
---------------------------
The Game Boy display works by absorbing light instead of emitting it.
Because of this "subtractive" nature, as well as the overall reduced
contrast and other display artifacts on monochrome handhelds, many
tests allow inverting grays with the Select button.

Though the NES version of 240p Test Suite uses about 52 KiB of ROM
data, the [cartridges sold by Catskull] are limited to 32 KiB.
Fortunately, the graphics for several tests are smaller than on a
240p platform, which makes the menu, Linearity, Sharpness, Drop
Shadow, and Scroll Test smaller.  I managed to make some tests' help
text more concise.  Easily readable VRAM helps, as does the LR35902
CPU's better code density for anything that doesn't use structs or
parallel arrays.

* 100 IRE: Extended into Motion blur.
* Linearity: Only one pixel aspect ratio (square) instead of 2 (NTSC
  and PAL), and square pixels allow calculating the grid at runtime.
* Sound Test: No "Crowd" because GB PCM is limited to 4 bits.
* Alternate 240p/480i: SGB and GB Player offer no control over
  the host systems' interlace modes except through SGB JUMP.

Though Game Boy Color enhancements just barely fit into 32 KiB,
Super Game Boy enhancements are omitted due to lack of ROM space
and more importantly lack of time.

[cartridges sold by Catskull]: https://catskullelectronics.com/32kcart

Legal
-----
Copyright 2018 Damian Yerrick  
License: GNU GPL version 2 or later for anything specific to 144p
Test Suite; zlib for generic parts
