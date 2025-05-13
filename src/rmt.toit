// Copyright (C) 2025 Toit contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import rmt
import bitmap show blit OR
import .pixel-strip

class RmtEncodingPixelStrip_ extends PixelStrip:
  static RESOLUTION_ ::= 20_000_000  // 20MHz, with 50ns ticks.
  // Durations in ns.
  static T0H_ ::= 350
  static T0L_ ::= 800
  static T1H_ ::= 700
  static T1L_ ::= 600

  out_/rmt.Out? := ?
  encoder_/rmt.Encoder? := ?

  constructor pixels/int --pin/gpio.Pin --bytes-per-pixel/int=3 --memory-block-count/int=1:
    out_ = rmt.Out
        pin
        --memory-blocks=memory-block-count
        --resolution=RESOLUTION_

    null-signal := rmt.Signals.alternating
        --resolution=RESOLUTION_
        --first-level=1
        --ns-durations=[T0H_, T0L_]
    one-signal := rmt.Signals.alternating
        --resolution=RESOLUTION_
        --first-level=1
        --ns-durations=[T1H_, T1L_]
    encoder_ = rmt.Encoder --msb {
      0: null-signal,
      1: one-signal,
    }

    super pixels --bytes-per-pixel=bytes-per-pixel

  close -> none:
    if out_ != null:
      out_.close
      out_ = null
    if encoder_ != null:
      encoder_.close
      encoder_ = null

  is-closed -> bool:
    return out_ == null

  output-interleaved interleaved-data/ByteArray -> none:
    out_.write interleaved-data --encoder=encoder_
