// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

// Two sparks start from each end of the strip.  When they meet,
// the whole strip explodes in a white explosion that fades.

import bitmap show bytemap_zap
import pixel_strip show *

PIXELS ::= 300

END ::= 272

TX ::= 17

main:
  neopixels := UartPixelStrip PIXELS --pin=TX --bytes_per_pixel=4
  //neopixels := I2SPixelStrip PIXELS --pin=TX --bytes_per_pixel=4
  r := ByteArray PIXELS
  g := ByteArray PIXELS
  b := ByteArray PIXELS
  w := ByteArray PIXELS

  while true:
    // All pixels black.
    neopixels.output r g b w

    // White sparks from each end, with a red tail.  Meet in the middle.
    (END / 2).repeat:
      set_both_ends r it 255
      set_both_ends g it 255
      set_both_ends b it 255
      set_both_ends w it 255
      set_both_ends r it-1 255
      set_both_ends g it-1 0
      set_both_ends b it-1 0
      set_both_ends w it-1 0
      set_both_ends r it-2 128
      set_both_ends r it-3 64
      set_both_ends r it-4 32
      set_both_ends r it-5 16
      set_both_ends r it-5 8
      set_both_ends r it-6 4
      set_both_ends r it-7 2
      set_both_ends r it-8 1
      set_both_ends r it-9 0
      neopixels.output r g b w
      sleep --ms=1

    // Explosion on the whole strip in white, fading away to black.
    for i := 255; i > -10; i -= 10:
      bytemap_zap r (max i 0)
      bytemap_zap g (max i 0)
      bytemap_zap b (max i 0)
      bytemap_zap w (max i 0)
      neopixels.output r g b w
      sleep --ms=1

set array i v:
  if 0 <= i < array.size: array[i] = v

set_both_ends array i v:
  if 0 <= i < array.size: array[i] = v
  i = END - i
  if 0 <= i < array.size: array[i] = v
