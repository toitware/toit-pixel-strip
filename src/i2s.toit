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

  static BUFFER-SIZE_ ::= 128
  // The SDK uses six DMA buffers of 240 stereo 16-bit frames (960 bytes).
  // One extra buffer covers the FIFO and the strip's final reset interval.
  static DMA-BUFFER-SIZE_ ::= 960
  static DRAIN-BUFFER-COUNT_ ::= 7
  static IDLE_ ::= ByteArray DMA-BUFFER-SIZE_

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
    encoded-size := round-up (pixels * bytes-per-pixel * 4) BUFFER-SIZE_
    // Lead every frame with 320 us low, including back-to-back frames.
    out-buf_ = ByteArray BUFFER-SIZE_ + encoded-size
    encoded := out-buf_[BUFFER-SIZE_..]
    out-buf-0_ = encoded[0..]
    out-buf-1_ = encoded[1..]
    out-buf-2_ = encoded[2..]
    out-buf-3_ = encoded[3..]

    bus_ = i2s.Bus --master --tx=pin --ws=null --sck=null
    bus_.configure --sample-rate=100_000 --bits-per-sample=16

    super pixels --bytes-per-pixel=bytes-per-pixel

  close->none:
    if not bus_: return
    try:
      if bus-started_:
        // Queue more idle data than the DMA ring and FIFO can hold. Waiting
        //   for buffer space drains the final frame and reset before stopping.
        DRAIN-BUFFER-COUNT_.repeat: bus_.write IDLE_
    finally:
      bus_.close
      bus_ = null
      bus-started_ = false

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

    // Keep the bus running. The SDK clears transmitted buffers, so underruns
    //   emit low. Output returns once the frame has been copied into DMA buffers.
    if not bus-started_:
      written := bus_.preload out-buf_
      bus_.start
      bus-started_ = true
      if written < out-buf_.size: bus_.write out-buf_[written..]
    else:
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
