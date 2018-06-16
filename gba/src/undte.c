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
      unsigned char *pair = dte_replacements[ctoprint - DTE_MIN_CODEUNIT];
      if (dtedepth < DTE_STACK_SIZE) {
        dtestack[dtedepth++] = pair[1];
      }
      ctoprint = pair[0];
    }
  }
}
