The following instructions for making a cartridge of 240p Test Suite
for NES are based on instructions in [Ice Man's post] on NESdev BBS.

The suite uses the [UNROM board] (iNES mapper 2) with horizontal
nametable arrangement, called "vertical mirroring" by the
emulation community. You can pull the circuit board out of any
[game using UNROM] and replace the mask ROM with a 27C512, 29F512,
or equivalent 64Kx8-bit or bigger 5 V UV EPROM or flash memory.
Or you can buy a [discrete repro board] from RetroStage and
populate it with the necessary discrete parts and key CIC.

NES ROM images contain a 16-byte header, starting with `4E 45 53 1A`.
This describes the game's intended circuit board to an emulator.
Because you have an actual circuit board, you'll want to chop off the
first 16 bytes in a hex editor, resulting in a binary image 65,536
bytes in size.  And if you're using a memory larger than a 27C512,
you'll need to double up the ROM to fill it.  The `nestobin.py`
program in the `tools` folder automates this, or if you don't have
Python installed, you can use FamiROM, linked in Ice Man's post.

If using a donor board, you'll need a "line" head screwdriver
(sometimes called "GameBit") to open the cartridge shell.
First desolder the program ROM on the right side of the board.
This is a 28-pin mask ROM, marked "PRGROM" or "U1 PRG" on the
PCB.  DO NOT REMOVE the skinny chips (LS161, LS32, and CIC)
or the CHR RAM.  Clean the holes.

After you've burned the binary to your EPROM using an EPROM
programmer, solder it into the PCB.  The pinout for RetroStage
reproduction boards should match that of an EPROM.  If you use
a Nintendo donor board, you'll need to rearrange a few pins
slightly using short pieces of wire.

For 28-pin EPROMs (27C512, 29F512):

1. Bend up pin 22
2. Solder pin 22 to GND (/OE)

For 32-pin EPROMs (27C010, 27C020, 27C040, 29F010, 29F020, 29F040):

1. Bend up pin 1, 2, 24, 31 and 32
2. Solder pin 2 to hole 22 (A16)
3. Solder pin 24 to GND (/OE)
4. Solder pin 30 to hole 28 (+5V), or leave NC for 27c010
5. Solder pin 32 to hole 28 (+5V)

When using a 32 pin EPROM, make sure the capacitor on the right side
of the PRG ROM is removed and soldered in from the bottom of the
board.  Otherwise the EPROM will not fit in properly, and the cart
won't close.  Take care to solder it back in with correct polarity.
You may also have to cut off some plastic next to one of the screw
holes in the case to fit the larger EPROM.

Some copies of UNROM games published by Konami have a white "24" on
the back label.  Instead of a Nintendo UNROM board, these contain a
compatible board produced by Konami that has two key differences.
First, the ROM pinout is more similar to that of EPROM, needing much
less rework.  Second, the ROM is installed pointing to the front and
back instead of left and right, leaving more room for a 32-pin
memory.  See the [CrackOut prototype] for an example.

Finally, set the nametable arrangement to horizontal.  On Nintendo
donor boards, make sure H is closed with solder and V is open.
The majority of UNROM games have H closed; for the few with V
closed, you'll need to resolder the pads.  RetroStage boards use the
opposite "mirroring" convention, so close VERT and leave HORIZ open.

The full package also includes executables for BNROM (since 0.13),
SGROM/SNROM (since 0.23), and TGROM/TNROM (since 0.23) cartridge
boards.  Why BNROM when only _Deadly Towers_ uses it?

1. _Deadly Towers_ is a fairly common yet poorly received game.
   Turning them into 240p carts will make the world a better place.
2. AMROM, ANROM, and AOROM boards can be modified to behave as
   BNROM by cutting the trace from the 74161 to VRAM A10 and
   connecting PPU A10 in its place.  For example, you could upcycle
   _A Nightmare on Elm Street_ or some other poorly received
   LJN game that Rare was unlucky enough to be involved in.
3. Reproduction boards for BNROM don't need the 74HC32.  Save money!

SGROM and TGROM are there for two reasons.  One is to run on MMC1 or
MMC3 donor cartridges for FamicomBox, a console variant installed in
hotels.  Its cartridges have a special CIC that hasn't been cloned
the way NES CIC has.  The other is multicarts using MMC3 clones.

The stand-alone MDFourier tone generator ROM can run on a mapper 218
cartridge, which has only a PRG ROM and no CHR ROM or mapper.

When including 240p Test Suite in an [Action 53] compilation,
do this to ensure accuracy of MDFourier results:

1. In `nes/src/global.inc`, set `IS_MULTICART` to nonzero and rebuild
2. In your compilation's `a53.cfg`, set `exitmethod=none` for the
   240p Test Suite ROM so that Start+Reset can work.


[Ice Man's post]: http://forums.nesdev.com/viewtopic.php?p=159747#p159747
[UNROM board]: http://bootgod.dyndns.org:7777/pcb.php?PcbID=425+426+427+428+429+430+432+433+434
[game using UNROM]: http://bootgod.dyndns.org:7777/search.php?keywords=unrom&kwtype=pcb&group=groupid
[discrete repro board]: http://www.retrostage.net/nes_discretes.htm
[CrackOut prototype]: http://bootgod.dyndns.org:7777/profile.php?id=4618
[Action 53]: https://github.com/pinobatch/action53
