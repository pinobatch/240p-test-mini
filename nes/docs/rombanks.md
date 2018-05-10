There's a bit of "magic" involved in getting BNROM and UNROM to
build from one source code.

The BNROM version has two 32K banks: 0 and 1.  Almost all code and
data not related to compressed CHR and maps is in bank 1.  These
segments are in bank 0:

* `PB53CODE` (BNROM: 0; UNROM: 3)  
  CHR and map decompression code
* `PB53TABLES` (BNROM: 0; UNROM: 3)  
  List of PB53 (CHR) and SB53 (CHR + map + palette) addresses
* `BANK00` and `BANK01` (BNROM: 0; UNROM: 0 and 1)  
  Compressed CHR and map data
* `GATEDATA` (BNROM: 0; UNROM: 1)  
  Files that are decompressed not to VRAM but to main memory, such as
  the tilemap in the *Kiki Kaikai*-inspired vertical scroll test and
  the sprite in the shadow sprite test
* `STUB0` (BNROM: 0; UNROM: does not exist)  
  If the NES powers on in this bank, immediately switch to bank 1

The tricky part is `GATEDATA`.  Because the decompression code is not
in the same bank as the test screen's code, calls need to go through
`unpb53_gate` to switch banks.  So the test program switches to bank
1 and calls the gate.  In BNROM, switching to bank 1 is a no-op, and
the gate switches to bank 0 to perform the decompression.  In UNROM,
switching to bank 1 actually brings the relevant data into view, but
the gate is a no-op because decompression is in the fixed bank.
