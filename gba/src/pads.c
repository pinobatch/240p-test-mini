#include <gba_input.h>
#include "global.h"

#define DAS_DELAY 12
#define DAS_SPEED 3

// scanKeys in libgba isn't quite flexible enough for what I'm doing.
// I want to make only some keys autorepeat and not others.
// So I just translated my NES and GB autorepeat stuff line by line.
unsigned short cur_keys, new_keys, das_keys, das_timer;

unsigned int read_pad(void) {
  unsigned int keys = (~REG_KEYINPUT) & 0x03ff;
  new_keys = keys & ~cur_keys;
  cur_keys = keys;
  return keys;
}

unsigned int autorepeat(unsigned int allowed_keys) {
  // If no eligible keys are held, skip all autorepeat processing
  unsigned int allowed_held = allowed_keys & cur_keys;
  if (!allowed_held) return new_keys;
  
  // If any keys were newly pressed, set the eligible keys among them
  // as the autorepeating set.  For example, changing from Up to
  // Up+Right sets Right as the new autorepeating set.
  if (new_keys) {
    das_keys = new_keys & allowed_keys;
    das_timer = DAS_DELAY;
  } else {

    // If time has expired, merge in the autorepeating set
    --das_timer;
    if (das_timer == 0) {
      new_keys |= das_keys;
      das_timer = DAS_SPEED;
    }
  }
  return new_keys;
}
