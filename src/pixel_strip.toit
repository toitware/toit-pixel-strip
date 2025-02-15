// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .uart
import .i2s
import bitmap show blit
import gpio

export I2sPixelStrip UartPixelStrip

/**
A driver that sends data to attached WS2812B LED strips, sometimes
  called Neopixel.
*/

abstract class PixelStrip:
  pixels_/int := ?
  bytes-per-pixel_ := ?
  inter_ := ?

  inter-1_ := ?
  inter-2_ := ?
  inter-3_ := null

  /// The number of pixels in the strip.
  pixels->int: return pixels_

  constructor .pixels_/int --bytes-per-pixel=3:
    bytes-per-pixel_ = bytes-per-pixel
    inter_ = ByteArray pixels_ * bytes-per-pixel_
    inter-1_ = inter_[1..]
    inter-2_ = inter_[2..]
    if bytes-per-pixel > 3: inter-3_ = inter_[3..]

  /**
  A driver that sends data to attached WS2812B LED strips, sometimes
    called Neopixel.  The UART driver is used on the given $pin.

  Normally you need to invert the TX pin of a UART to use it for
    WS2812B LED strips.  Often you also need a level shifter to
    convert from 3.3V to 5V.  If your level shifter also inverts
    the pin you can disable the inverted pin support with $invert-pin.
  If your strip is RGB (24 bits per pixel), leave $bytes-per-pixel at 3.
    For SK8612 RGBW strips (usually with natural or warm white) specify
    $bytes-per-pixel as 4.
  Because of the high baud rate, the system will default to running
    the UART with a high priority.  However your ESP32 may not have
    the interrupt resources for that, in which case an exception will
    be thrown.  In this case, set $high-priority to false.
  # Note
  You must update the whole strip.  If your strip has 15 pixels
    it is not supported to call this constructor with $pixels of 11 in
    order to update only the first 11 pixels.  This is likely to cause
    color errors on the 12th pixel.
  */
  constructor.uart pixels/int --pin/gpio.Pin --invert-pin/bool=true --bytes-per-pixel/int=3 --high-priority/bool?=null:
    return UartPixelStrip_ pixels --pin=pin --invert-pin=invert-pin --bytes-per-pixel=bytes-per-pixel --high-priority=high-priority

  constructor.uart pixels/int --path/string --bytes-per-pixel/int --high-priority/bool?=null:
    return UartPixelStrip_ pixels --path=path --bytes-per-pixel=bytes-per-pixel --high-priority=high-priority

  /**
  Takes three or four byte arrays of pixel values (depending on the number of
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte arrays, so you can reuse them for the next
    frame.
  The pixel hardware uses a pause in the transmission to detect the
    start of the next frame of image data.  Therefore you should leave
    a few milliseconds before calling this method again.  If your program
    generates the next frame too fast you may have to add sleep--ms=2 after
    each call to this method.
  */
  output red/ByteArray green/ByteArray blue/ByteArray white/ByteArray?=null -> none:
    if white == null and bytes-per-pixel_ >= 4: throw "INVALID_ARGUMENT"
    if white != null and bytes-per-pixel_ < 4: throw "INVALID_ARGUMENT"
    if red.size < pixels_ or green.size < pixels_ or blue.size < pixels_ or (white and white.size < pixels_): throw "INVALID_ARGUMENT"
    // Interleave red, green, blue, and white.
    blit green inter_   pixels_ --destination-pixel-stride=bytes-per-pixel_
    blit red   inter-1_ pixels_ --destination-pixel-stride=bytes-per-pixel_
    blit blue  inter-2_ pixels_ --destination-pixel-stride=bytes-per-pixel_
    if white:
      blit white inter-3_ pixels_ --destination-pixel-stride=bytes-per-pixel_
    output-interleaved inter_

  /**
  Takes one byte array of pixel values, interleaved in GRB order, or
    GRBW order for strips with 4 bytes per pixel.
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte array, so you can reuse it for the next
    frame.
  */
  abstract output-interleaved interleaved-data/ByteArray -> none

  abstract close -> none
  abstract is-closed -> bool
