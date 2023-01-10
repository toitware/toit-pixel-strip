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
  bytes_per_pixel_ := ?
  inter_ := ?

  inter_1_ := ?
  inter_2_ := ?
  inter_3_ := null

  /// The number of pixels in the strip.
  pixels->int: return pixels_

  constructor .pixels_/int --bytes_per_pixel=3:
    bytes_per_pixel_ = bytes_per_pixel
    inter_ = ByteArray pixels_ * bytes_per_pixel_
    inter_1_ = inter_[1..]
    inter_2_ = inter_[2..]
    if bytes_per_pixel > 3: inter_3_ = inter_[3..]

  /**
  A driver that sends data to attached WS2812B LED strips, sometimes
    called Neopixel.  The UART driver is used on the given $pin.

  Normally you need to invert the TX pin of a UART to use it for
    WS2812B LED strips.  Often you also need a level shifter to
    convert from 3.3V to 5V.  If your level shifter also inverts
    the pin you can disable the inverted pin support with $invert_pin.
  If your strip is RGB (24 bits per pixel), leave $bytes_per_pixel at 3.
    For SK8612 RGBW strips (usually with natural or warm white) specify
    $bytes_per_pixel as 4.
  Because of the high baud rate, the system will default to running
    the UART with a high priority.  However your ESP32 may not have
    the interrupt resources for that, in which case an exception will
    be thrown.  In this case, set $high_priority to false.
  # Note
  You must update the whole strip.  If your strip has 15 pixels
    it is not supported to call this constructor with $pixels of 11 in
    order to update only the first 11 pixels.  This is likely to cause
    color errors on the 12th pixel.
  */
  constructor.uart pixels/int --pin/gpio.Pin --invert_pin/bool=true --bytes_per_pixel/int=3 --high_priority/bool?=null:
    return UartPixelStrip_ pixels --pin=pin --invert_pin=invert_pin --bytes_per_pixel=bytes_per_pixel --high_priority=high_priority

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
    if white == null and bytes_per_pixel_ >= 4: throw "INVALID_ARGUMENT"
    if white != null and bytes_per_pixel_ < 4: throw "INVALID_ARGUMENT"
    if red.size < pixels_ or green.size < pixels_ or blue.size < pixels_ or (white and white.size < pixels_): throw "INVALID_ARGUMENT"
    // Interleave red, green, blue, and white.
    blit green inter_   pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit red   inter_1_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit blue  inter_2_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    if white:
      blit white inter_3_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    output_interleaved inter_

  /**
  Takes one byte array of pixel values, interleaved in GRB order, or
    GRBW order for strips with 4 bytes per pixel.
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte array, so you can reuse it for the next
    frame.
  */
  abstract output_interleaved interleaved_data/ByteArray -> none

  abstract close -> none
  abstract is_closed -> bool
