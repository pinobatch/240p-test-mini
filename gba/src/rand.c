/*
Pseudorandom number generator
Copyright 2018 Damian Yerrick

This work is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any
damages arising from the use of this work.

Permission is granted to anyone to use this work for any purpose,
including commercial applications, and to alter it and redistribute
it freely, subject to the following restrictions:

1. The origin of this work must not be misrepresented; you must
   not claim that you wrote the original work. If you use
   this work in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original work.
3. This notice may not be removed or altered from any source
   distribution.

"Source" is the preferred form of a work for making changes to it.

*/
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
