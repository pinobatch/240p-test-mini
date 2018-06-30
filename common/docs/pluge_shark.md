PLUGE Shark
===========

The Pluge Contrast test in 240p Test Suite (for Sega Genesis) version
1.16 displays a [32x32-pixel shark head mascot][1] from Toaplan's
game _Fire Shark_ as a repeating pattern.  When I discovered that
we probably don't have the rights to this icon, I drew my own
replacement based on the pose used by emoji fonts' renderings
of the character 🦈 [SHARK (U+1F988)][2], added in Unicode 11.
I made a bit more cartoonish, including a large eye like those
of the icon, and colored it based on the closest color in the
[Bisqwit palette on wiki.nesdev.com][3] to each color in the icon.

* Outline: #000000 (NES $0F)
* Background mark: #003C00 (NES $0A)
* Background space: #077704 (NES $1A)
* Shark body: #131F7F (NES $02)
* Shark underbody: #00727D (NES $1C)
* Shark eye and teeth: #AEAEAE (NES $10)
* Tongue (not used): #BD3C30 (NES $16)

Though I give NES equivalents for all seven colors, I ended up not
drawing a visible tongue.  And on 2bpp platforms (NES and GB), the
background mark and space will have to share colors with the shark.

Copyright 2018 Damian Yerrick
This shark icon and its description are licensed under
[Creative Commons Attribution 4.0 International][4] (CC BY 4.0).


[1]: https://github.com/ArtemioUrbina/240pTestSuite/blob/0a16fcb3bdd137767a892eb17c8f9aa565456e17/240psuite/SNES/240pSuite/fireshark.bmp
[2]: https://emojipedia.org/shark/
[3]: https://wiki.nesdev.com/w/index.php/File:Savtool-swatches.png
[4]: https://creativecommons.org/licenses/by/4.0/