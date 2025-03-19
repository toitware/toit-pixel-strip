// Copyright (C) 2025 Toit contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import rmt
import bitmap show blit OR
import .pixel-strip

class RmtEncodingPixelStrip_ extends PixelStrip:
  // Durations in ticks.
  // A tick is 0.05us.
  static T0H_ ::= 7   // 0.35 us
  static T0L_ ::= 16  // 0.8 us
  static T1H_ ::= 14  // 0.7 us
  static T1L_ ::= 12  // 0.6 us

  signals_/rmt.Signals
  out_/rmt.Channel? := ?

  constructor pixels/int --pin/gpio.Pin --bytes-per-pixel/int=3 --memory-block-count/int=1:
    needed-signals := pixels * (bytes-per-pixel * 8 * 2)
    needed-memory := needed-signals * rmt.Signals.BYTES-PER-SIGNAL
    out_ = rmt.Channel --output
        pin
        --memory-block-count=memory-block-count
        --clk-div=4  // The clock is at 80MHz. so dividing by 4 gives 0.05us ticks.
        --idle-level=0
    signals_ = rmt.Signals.from-bytes (ByteArray.external needed-memory)

    super pixels --bytes-per-pixel=bytes-per-pixel

  close -> none:
    if out_ != null:
      out_.close
      out_ = null

  is-closed -> bool:
    return out_ == null

  output-interleaved interleaved-data/ByteArray -> none:
    signals := signals_
    signal-index := 0
    for i := 0; i < interleaved-data.size; i++:
      byte := interleaved-data[i]
      mask := 0b10000000
      for j := 0; j < 8; j++:
        bit := byte & mask
        mask >>= 1
        if bit == 0:
          signals.set signal-index++ --period=T0H_ --level=1
          signals.set signal-index++ --period=T0L_ --level=0
        else:
          signals.set signal-index++ --period=T1H_ --level=1
          signals.set signal-index++ --period=T1L_ --level=0

    out_.write signals
