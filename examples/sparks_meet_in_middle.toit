// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

// Two sparks start from each end of the strip.  When they meet,
// the whole strip explodes in a white explosion that fades.

import bitmap show bytemap-zap
import pixel-strip show *
import gpio

PIXELS ::= 300

END ::= 272

TX ::= 17

main:
  neopixels := PixelStrip.uart PIXELS --pin=(gpio.Pin TX) --bytes-per-pixel=4
  //neopixels := PixelStrip.i2s PIXELS --pin=(gpio.Pin TX) --bytes_per_pixel=4
  r := ByteArray PIXELS
  g := ByteArray PIXELS
  b := ByteArray PIXELS
  w := ByteArray PIXELS

  while true:
    // All pixels black.
    neopixels.output r g b w

    // White sparks from each end, with a red tail.  Meet in the middle.
    (END / 2).repeat:
      set-both-ends r it 255
      set-both-ends g it 255
      set-both-ends b it 255
      set-both-ends w it 255
      set-both-ends r (it - 1) 255
      set-both-ends g (it - 1) 0
      set-both-ends b (it - 1) 0
      set-both-ends w (it - 1) 0
      set-both-ends r (it - 2) 128
      set-both-ends r (it - 3) 64
      set-both-ends r (it - 4) 32
      set-both-ends r (it - 5) 16
      set-both-ends r (it - 5) 8
      set-both-ends r (it - 6) 4
      set-both-ends r (it - 7) 2
      set-both-ends r (it - 8) 1
      set-both-ends r (it - 9) 0
      neopixels.output r g b w
      sleep --ms=2

    // Explosion on the whole strip in white, fading away to black.
    for i := 255; i > -10; i -= 10:
      bytemap-zap r (max i 0)
      bytemap-zap g (max i 0)
      bytemap-zap b (max i 0)
      bytemap-zap w (max i 0)
      neopixels.output r g b w
      sleep --ms=2

set array i v:
  if 0 <= i < array.size: array[i] = v

set-both-ends array i v:
  if 0 <= i < array.size: array[i] = v
  i = END - i
  if 0 <= i < array.size: array[i] = v
