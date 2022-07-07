// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

// The Pycom gpy has a single WS2812B-compatible multicolor LED.

import bitmap show bytemap_zap
import pixel_strip show *
import gpio

/// 32 brightnesses that appear evenly spaced.
BRIGHTNESSES := get_brightnesses_

get_brightnesses_:
  result := []
  for power := 8; power > 0; power--:
    STEPS_.do:
      result.add (it * (1 << power)) >> 5
  return result

STEPS_ ::= [27, 23, 19, 16]  // Log distributed.

// Gpy has the colored LED on GPIO pin 0.
TX ::= 0

main:
  neopixel := PixelStrip.uart 1 --pin=(gpio.Pin TX) --bytes_per_pixel=3
  r := ByteArray 1
  g := ByteArray 1
  b := ByteArray 1

  print BRIGHTNESSES.size

  5.repeat:
    // All pixels black.
    neopixel.output r g b

    // Fade from white to black.
    BRIGHTNESSES.do:
      r[0] = it
      g[0] = it
      b[0] = it
      sleep --ms=100
      neopixel.output r g b

    // Fade from red to black.
    BRIGHTNESSES.do:
      r[0] = it
      sleep --ms=100
      neopixel.output r g b

    // Fade from green to black.
    BRIGHTNESSES.do:
      g[0] = it
      sleep --ms=100
      neopixel.output r g b
