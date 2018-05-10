# 240p-test-mini
Size-optimized ports of Artemio's 240p Test Suite to 8-bit consoles

I've remade Artemio Urbina's [240p Test Suite] for the Nintendo Entertainment
System and Game Boy compact video game system.  The rewrites are in assembly
language for speed and size efficiency.  Some functionality may be rearranged
slightly to fit the controller or to combine the function of similar tests.
Some help pages have been rewritten for completeness, conciseness, and English
usage improvements.  Some tests' graphics have been replaced to keep the
software free.

To get set up to build the NES port, see [nrom-template] instructions.
(Hint: Install GNU Make, Coreutils, Python 3, Pillow, cc65.)  The port to
Game Boy (called "144p Test Suite" because of the nature of its video output)
additionally requires [RGBDS].

Like Artemio's original versions, these ports of 240p Test Suite are free
software under the GNU General Public License, version 2 or later.

[240p Test Suite]: https://github.com/ArtemioUrbina/240pTestSuite
[nrom-template]: https://github.com/pinobatch/nrom-template
[RGBDS]: https://github.com/rednex/rgbds
