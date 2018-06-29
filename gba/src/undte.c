/*
Digram tree encoding (DTE) unpacker
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

#define DTE_STACK_SIZE 8
#define DTE_MIN_CODEUNIT 136
#define MIN_PRINTABLE 32

extern const unsigned char dte_replacements[][2];

/**
 * Decompresses digram tree encoded (DTE) text from src to dst.
 * Stops at the first code unit less than MIN_PRINTABLE.
 * @param src source address
 * @param dst destination address
 * @param srcend If not NULL, 1 byte after final low code unit
 * @return pointer to low code unit in dst
 */
char *undte_src(char *dst, const char *src, const char **srcend) {
  unsigned char dtestack[DTE_STACK_SIZE];
  unsigned int dtedepth = 0;
  unsigned int ctoprint = 0;

  while (1) {
    // charloop
    
    // If there's a code on the stack, print it.  Otherwise,
    // retrieve a code from the compressed text.
    if (dtedepth > 0) {
      ctoprint = (unsigned char)dtestack[--dtedepth];
    } else {
      ctoprint = (unsigned char)*src++;
    }
    while (1) {
      // print_code_a
      // If not a pair, save it to the string.
      if (ctoprint < DTE_MIN_CODEUNIT) {
        *dst = ctoprint;
        if (ctoprint < MIN_PRINTABLE) {
          if (srcend) *srcend = src;
          return dst;
        }
        ++dst;
        break;
      }

      // code_is_pair
      const unsigned char *pair = dte_replacements[ctoprint - DTE_MIN_CODEUNIT];
      if (dtedepth < DTE_STACK_SIZE) {
        dtestack[dtedepth++] = pair[1];
      }
      ctoprint = pair[0];
    }
  }
}
