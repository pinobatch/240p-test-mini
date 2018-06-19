#include "global.h"

// This uses the same linear congruential generator as cc65's
// random function, but with different tempering.

static unsigned int seed = 1;

void lcg_srand(unsigned int in_seed) {
  seed = in_seed;
}

int lcg_rand(void) {
  seed = (seed * 0x01010101) + 0x31415927;
  return (seed ^ (seed >> 16)) & 0xFFFF;
}
