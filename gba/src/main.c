#include <gba_video.h>
#include <gba_interrupt.h>
#include <gba_systemcalls.h>
#include <gba_input.h>
#include <stdio.h>
#include <stdlib.h>
#include "global.h"

// Notes:
// iprintf is devkitARM-specific printf without float support.
// Printing \x1b[yy;xxH to stdout will seek to xx,yy.
// fputs(..., stdout) avoids linking in printf, cutting .gba size 
// from 89K to 46K.  But this is nowhere near as dramatic as the gain
// for switching from <iostream> to <cstdio>.
// But consoleDemoInit() and fputs() are still fairly big because
// they cause the devoptab infrastructure to be linked in.

//---------------------------------------------------------------------------------
// Program entry point
//---------------------------------------------------------------------------------

int main(void) {

  // Enable vblank IRQ, without which VBlankIntrWait() won't work
  irqInit();
  irqEnable(IRQ_VBLANK);

//	consoleDemoInit();
//	fputs("\x1b[5;9HHello World!\n", stdout);

  while (1) {
    helpscreen(0, KEY_B|KEY_A|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT);
    activity_linearity();
    lame_boy_demo();
  }
}
