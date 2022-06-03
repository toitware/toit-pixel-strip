// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import i2s
import bitmap show blit OR
import .pixel_strip

/**
A driver that sends data to attached WS2812B LED strips, sometimes
  called Neopixel.  The I2S driver is used.

Deprecated.  The current esp-idf versions seem to have a bug
  where they replay old data instead of sending zeros on the
  I2S bus.  This makes this driver unreliable, so we are
  deprecating it until we can resolve the issue.  Please use
  $UartPixelStrip instead.
*/
class I2sPixelStrip extends PixelStrip:
  out_buf_ := ?
  out_buf_0_ := ?
  out_buf_1_ := ?
  out_buf_2_ := ?
  out_buf_3_ := ?
  bus_ /i2s.Bus? := ?
  pin_ /gpio.Pin? := null // Only set if the pin needs closing.

  static BUFFER_SIZE_ ::= 128
  reset_ := ByteArray BUFFER_SIZE_

  /**
  Constructs a pixel-strip class controlling the strip with the i2s peripheral.

  The $pin should be of type $gpio.Pin. The use of a pin number for $pin is
    deprecated.

  If your strip is RGB (24 bits per pixel), leave $bytes_per_pixel at
    3.  For RGB+WW (warm white) strips with 32 bits per pixel, specify
    $bytes_per_pixel as 4.
  */
  constructor pixels/int --pin/any --bytes_per_pixel=3:
    out_buf_ = ByteArray
      round_up
        pixels * bytes_per_pixel * 4
        BUFFER_SIZE_
    out_buf_0_ = out_buf_[0..]
    out_buf_1_ = out_buf_[1..]
    out_buf_2_ = out_buf_[2..]
    out_buf_3_ = out_buf_[3..]

    tx /gpio.Pin := ?
    if pin is int:
      tx = gpio.Pin.out pin
      pin_ = tx
    else:
      tx = pin

    bus_ = i2s.Bus --tx=tx --sample_rate=100_000 --bits_per_sample=16 --buffer_size=BUFFER_SIZE_

    super pixels --bytes_per_pixel=bytes_per_pixel

  close->none:
    if bus_:
      bus_.close
      bus_ = null
    if pin_:
      pin_.close
      pin_ = null

  is_closed -> bool:
    return not bus_

  output_interleaved interleaved_data/ByteArray -> none:
    // TODO: We could save some memory using a 3-bit encoding of the signal
    // instead of the this 4-bit encoding.
    blit interleaved_data out_buf_3_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_0_
    blit interleaved_data out_buf_2_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_1_
    blit interleaved_data out_buf_1_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_2_
    blit interleaved_data out_buf_0_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_3_

    bus_.write reset_
    written := bus_.write out_buf_
    if written != out_buf_.size: print "Tried to write $out_buf_.size, wrote $written"

  static TABLE_0_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[it >> 6]
  static TABLE_1_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[(it >> 4) & 3]
  static TABLE_2_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[(it >> 2) & 3]
  static TABLE_3_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[it & 3]

  // We can output 2 bits of WS2812B protocol by using each nibble on the I2S
  // bus to shape a pulse for the WS2812B.

  static ENCODING_TABLE_2_BIT_ ::= #[
    0b1000_1000,   // 0b00
    0b1000_1110,   // 0b01
    0b1110_1000,   // 0b10
    0b1110_1110,   // 0b11
    ]
