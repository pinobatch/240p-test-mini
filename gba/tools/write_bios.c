#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "gba_bios.h"
static_assert(sizeof(gba_bios_bin) == 16384);
int main(void) {
  FILE *outfp = fopen("gba_bios.bin", "wb");
  if (!outfp) return EXIT_FAILURE;
  size_t written = fwrite(gba_bios_bin, sizeof gba_bios_bin, 1, outfp);
  fclose(outfp);
  return !written;
}
