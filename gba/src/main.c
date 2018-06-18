#include <gba_video.h>
#include <gba_interrupt.h>
#include <gba_systemcalls.h>
#include <gba_input.h>
#include <stdio.h>
#include <stdlib.h>
#include "global.h"

// It's a bit tricky to import a document ID into C.
extern const unsigned char helpsect_160p_test_suite_menu[];
extern const unsigned char helpsect_160p_test_suite[];
extern const unsigned char helpsect_about[];
extern const unsigned char helpsect_to_do[];

#define DOC_MENU ((unsigned int)helpsect_160p_test_suite_menu)
#define DOC_CREDITS ((unsigned int)helpsect_160p_test_suite)
#define DOC_ABOUT ((unsigned int)helpsect_about)
#define DOC_TODO ((unsigned int)helpsect_to_do)

// Notes:
// iprintf/siprintf is devkitARM-specific printf/sprintf without float
// support.  posprintf is an even smaller sprintf by Dan Posluns.
// Printing \x1b[yy;xxH to stdout will seek to xx,yy.
// fputs(..., stdout) avoids linking in printf, cutting .gba size 
// from 89K to 46K.  But this is nowhere near as dramatic as the gain
// for switching from <iostream> to <cstdio>.
// But consoleDemoInit() and fputs() are still fairly big because
// they cause the devoptab infrastructure to be linked in.

void activity_about(void);
void activity_credits(void);

static const activity_func page_one_handlers[] = {
  activity_pluge,
  activity_gcbars,
  activity_smpte,
  activity_601bars,
  activity_color_bleed,
  activity_cps_grid,
  activity_linearity,
  activity_gray_ramp,
  activity_solid_color,
  activity_motion_blur,
  activity_sharpness,
  activity_overscan,
};
static const activity_func page_two_handlers[] = {
  activity_shadow_sprite,
  activity_stopwatch,
  activity_megaton,
  activity_hill_zone_scroll,
  activity_kiki_scroll,
  activity_grid_scroll,
  activity_full_stripes,
  activity_backlight_zone,
  activity_sound_test,
  activity_audio_sync,
  lame_boy_demo,
  activity_about,
  activity_credits,
};
static const activity_func *activity_handlers[2] = {
  page_one_handlers,
  page_two_handlers
};

int main(void) {
  unsigned int last_page, last_y;

  // Enable vblank IRQ, without which VBlankIntrWait() won't work
  irqInit();
  irqEnable(IRQ_VBLANK);
  //activity_overscan();
  //helpscreen(DOC_TODO, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
  activity_credits();

  while (1) {
    unsigned int chosenpg = helpscreen(DOC_MENU, KEY_A|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT);
    last_page = help_wanted_page;
    last_y = help_cursor_y;
    
    // Start does About instead of the chosen item
    if (new_keys & KEY_START) {
      activity_about();
    } else {
      activity_handlers[chosenpg][help_cursor_y]();
    }
    help_cursor_y = last_y;
    help_wanted_page = last_page;
  }
}

void activity_about(void) {
  helpscreen(DOC_ABOUT, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
}

void activity_credits(void) {
  helpscreen(DOC_CREDITS, KEY_A|KEY_START|KEY_B|KEY_LEFT|KEY_RIGHT);
}

