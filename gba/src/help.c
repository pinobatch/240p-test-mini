#include <gba_video.h>
#include "global.h"

/* VRAM map

BG
C0-E1 (PT3#000-10F): VWF canvas (16 by 17 tiles)
F0-F7 (NT30): BG1 (back wall)
F8-FF (NT31): BG0 (VWF text)

OBJ
To be decided

*/

// Code units
#define LF 0x0A
#define GL_RIGHT 0x84
#define GL_LEFT 0x85
#define GL_UP 0x86
#define GL_DOWN 0x87

#define WINDOW_WIDTH 16  // Width of window in tiles not including left border

#define HELP_LINE_LEN 48
unsigned char help_line_buffer[HELP_LINE_LEN];
unsigned char help_bg_loaded = 0;
