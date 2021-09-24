// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .uart
import .i2s
import bitmap show blit

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
  Takes three or four byte arrays of pixel values (depending on the number of
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte arrays, so you can reuse them for the next
    frame.
  */
  output r/ByteArray g/ByteArray b/ByteArray w/ByteArray?=null -> none:

    if w == null and bytes_per_pixel_ >= 4: throw "INVALID_ARGUMENT"
    if w != null and bytes_per_pixel_ < 4: throw "INVALID_ARGUMENT"
    if r.size < pixels_ or g.size < pixels_ or b.size < pixels_ or (w and w.size < pixels_): throw "INVALID_ARGUMENT"
    // Interleave r, g, b, and w.
    blit g inter_   pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit r inter_1_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit b inter_2_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    if w:
      blit w inter_3_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    output_interleaved

  /**
  Takes one byte array of pixel values, interleaved in GRB order, or
    GRBW order for strips with 4 bytes per pixel.
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte array, so you can reuse it for the next
    frame.
  */
  abstract output_interleaved -> none
