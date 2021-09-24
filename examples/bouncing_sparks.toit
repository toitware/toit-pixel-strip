// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

// Sparks are white and have a fading tail of a random color.
// When they collide, one of them disappears and the other
// continues.  Someimes they spontaneously disappear.  Whenever
// a spark disappears, a new one appears somewhere else.

import bitmap show bytemap_zap
import pixel_strip show *

PIXELS ::= 300

TX ::= 17

class Spark:
  center/int := ?
  tail := 1
  direction := (random 2) * 2 - 1  // -1 or 1
  r := 128 + (random 128)
  g := 128 + (random 128)
  b := 128 + (random 128)

  constructor .center:
  constructor .center .tail:

  plot ra ga ba wa:
    add ra center r
    add ga center g
    add ba center b
    set wa center 255
    rd := r
    gd := g
    bd := b
    for x := 0; x < tail; x++:
      add ra center - x * direction rd
      add ga center - x * direction gd
      add ba center - x * direction bd
      rd = max 0 rd - 20
      gd = max 0 gd - 20
      bd = max 0 bd - 20

  advance:
    center += direction
    tail = min 30 tail + 1

main:
  neopixels := UartPixelStrip PIXELS --pin=TX --bytes_per_pixel=4
  r := ByteArray PIXELS
  g := ByteArray PIXELS
  b := ByteArray PIXELS
  w := ByteArray PIXELS

  neopixels.output r g b w

  sparks := List 5: Spark (random PIXELS) it * 2
  
  while true:
    bytemap_zap r 0
    bytemap_zap g 0
    bytemap_zap b 0
    bytemap_zap w 0

    sparks.do: it.plot r g b w

    neopixels.output r g b w

    // Sort them so we can do collision detection.
    sparks.sort: | a b | a.center - b.center

    sparks.size.repeat:
      spark := sparks[it]
      spark.advance

      if (random 100) == 0:
        spark = Spark (random PIXELS)
        sparks[it] = spark

      if it != 0:
        previous := sparks[it - 1]
        if spark.center == previous.center or (spark.direction != previous.direction and spark.center - spark.direction == previous.center):
          // Collision.  One dies.
          if (random 2) == 0:
            sparks[it - 1] = Spark (random PIXELS)
          else:
            sparks[it] = Spark (random PIXELS)

    sparks.do:
      if it.center < -20: it.center = PIXELS
      if it.center > PIXELS + 20 : it.center = 0

    sleep --ms=1

set array i v:
  if 0 <= i < array.size: array[i] = v

add array i v:
  if 0 <= i < array.size:
    array[i] = min 255 array[i] + v
