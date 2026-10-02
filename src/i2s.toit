// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import i2s
import bitmap show blit OR
import .pixel-strip

/**
A driver that sends data to attached WS2812B LED strips, sometimes
  called Neopixel.  The I2S driver is used.
*/
class I2sPixelStrip extends PixelStrip:
  out-buf_ := ?
  out-buf-0_ := ?
  out-buf-1_ := ?
  out-buf-2_ := ?
  out-buf-3_ := ?
  bus_ /i2s.Bus? := ?
  bus-started_/bool := false

  // ESP-IDF's default DMA ring has 6 buffers of 240 stereo 16-bit frames.
  static DMA-BUFFER-COUNT_ ::= 6
  // One DMA buffer of zeros, which keeps the line low.
  static IDLE_ ::= ByteArray 240 * 4

  /**
  Constructs a pixel-strip class controlling the strip with the i2s peripheral.

  The $pin is a GPIO number. Passing a $gpio.Pin is deprecated; provide the integer
    GPIO number instead.

  If your strip is RGB (24 bits per pixel), leave $bytes-per-pixel at
    3.  For RGB+WW (warm white) strips with 32 bits per pixel, specify
    $bytes-per-pixel as 4.
  */
  // __TYPE-MIGRATION__ pin: gpio.Pin. Deprecated. Provide an integer instead.
  // __TYPE-MIGRATION__ pin: int
  constructor pixels/int --pin/any --bytes-per-pixel=3:
    out-buf_ = ByteArray pixels * bytes-per-pixel * 4
    out-buf-0_ = out-buf_[0..]
    out-buf-1_ = out-buf_[1..]
    out-buf-2_ = out-buf_[2..]
    out-buf-3_ = out-buf_[3..]

    bus_ = i2s.Bus --master --tx=pin --ws=null --sck=null
    bus_.configure --sample-rate=100_000 --bits-per-sample=16

    super pixels --bytes-per-pixel=bytes-per-pixel

  close->none:
    if bus_:
      if bus-started_:
        // Push the last frame through the DMA ring before stopping.
        (DMA-BUFFER-COUNT_ + 1).repeat: bus_.write IDLE_
        bus_.stop
      bus_.close
      bus_ = null

  is-closed -> bool:
    return not bus_

  output-interleaved interleaved-data/ByteArray -> none:
    // TODO: We could save some memory using a 3-bit encoding of the signal
    // instead of this 4-bit encoding.
    // I2S sends the bytes of each 16-bit sample most-significant byte first.
    blit interleaved-data out-buf-1_ pixels_ * bytes-per-pixel_ --destination-pixel-stride=4 --lookup-table=TABLE-0_
    blit interleaved-data out-buf-0_ pixels_ * bytes-per-pixel_ --destination-pixel-stride=4 --lookup-table=TABLE-1_
    blit interleaved-data out-buf-3_ pixels_ * bytes-per-pixel_ --destination-pixel-stride=4 --lookup-table=TABLE-2_
    blit interleaved-data out-buf-2_ pixels_ * bytes-per-pixel_ --destination-pixel-stride=4 --lookup-table=TABLE-3_

    if not bus-started_:
      bus_.start
      bus-started_ = true
    // The bus keeps streaming between frames and emits silence (low) when it
    //   runs out of data. When writing resumes after such an underrun, ESP-IDF
    //   puts the first bytes into a partially filled buffer from the previous
    //   write, which has already been played, and then into the buffer that is
    //   about to be played. Lead with two DMA buffers of idle, so that only
    //   idle data is affected. The idle data also provides the reset interval.
    bus_.write IDLE_
    bus_.write IDLE_
    bus_.write out-buf_

  static TABLE-0_ ::= ByteArray 256: ENCODING-TABLE-2-BIT_[it >> 6]
  static TABLE-1_ ::= ByteArray 256: ENCODING-TABLE-2-BIT_[(it >> 4) & 3]
  static TABLE-2_ ::= ByteArray 256: ENCODING-TABLE-2-BIT_[(it >> 2) & 3]
  static TABLE-3_ ::= ByteArray 256: ENCODING-TABLE-2-BIT_[it & 3]

  // We can output 2 bits of WS2812B protocol by using each nibble on the I2S
  // bus to shape a pulse for the WS2812B.

  static ENCODING-TABLE-2-BIT_ ::= #[
    0b1000_1000,   // 0b00
    0b1000_1110,   // 0b01
    0b1110_1000,   // 0b10
    0b1110_1110,   // 0b11
    ]
