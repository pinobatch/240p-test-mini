# 240p-test-mini
Size-optimized ports of Artemio's 240p Test Suite to 8-bit consoles

I've remade Artemio Urbina's [240p Test Suite] for three more
platforms:

- Nintendo Entertainment System
- Game Boy and Game Boy Color (as "144p Test Suite")
- Game Boy Advance (as "160p Test Suite")

The NES and GB ports are in assembly language for speed and size
efficiency.  The GBA port is in C, but still size-optimized to fit
well within the 256 KiB multiboot limit.

The GB and GBA ports have a different name because their LCD video
timing doesn't match that of NTSC.  They exist to test not only the
TV but also the Super Game Boy or Game Boy Player accessory, which
behaves as a scaler.

Some functionality has been rearranged to fit the controller or
to combine the function of similar tests.  Some help pages have
been rewritten for completeness, conciseness, and English usage
improvements.  Some tests' graphics have been replaced to keep
the software free.

To get set up to build the NES port, install GNU Make, Coreutils,
Python 3, Pillow, and cc65 per [nrom-template] instructions.
(Hint: Install GNU Make, Coreutils, Python 3, Pillow, cc65.)
The port to Game Boy uses [RGBDS] instead of cc65.  The GBA port
uses devkitARM and libgba by [devkitPro], but Python 3 and Pillow
are still required to convert the proportional font.

Like Artemio's original versions, these ports of 240p Test Suite are free
software under the GNU General Public License, version 2 or later.

[240p Test Suite]: https://github.com/ArtemioUrbina/240pTestSuite
[nrom-template]: https://github.com/pinobatch/nrom-template
[RGBDS]: https://github.com/rednex/rgbds
[devkitPro]: https://devkitpro.org/wiki/Getting_Started