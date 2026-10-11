// Copyright (C) 2025 Toit contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import system
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
  // Newer WS2812B parts need more than 280us of low to latch a frame.
  static RESET_ ::= 300_000

  out_/rmt.Out? := ?
  encoder_/rmt.Encoder? := ?

  /**
  Passing a $gpio.Pin is deprecated; provide the integer GPIO number instead.
  */
  // __TYPE-MIGRATION__ pin: gpio.Pin. Deprecated. Provide an integer instead.
  // __TYPE-MIGRATION__ pin: int
  constructor pixels/int --pin/any --bytes-per-pixel/int=3 --memory-block-count/int?=null:
    // Four blocks give the interrupt-driven encoder room to tolerate Wi-Fi
    // and audio interrupt latency on the classic ESP32. Other variants have
    // fewer blocks; retain their existing default until measured separately.
    if memory-block-count == null:
      memory-block-count = system.architecture == system.ARCHITECTURE-ESP32 ? 4 : 1
    out_ = rmt.Out
        pin
        --memory-blocks=memory-block-count
        --resolution=RESOLUTION_

    zero-signal := rmt.Signals.alternating
        --resolution=RESOLUTION_
        --first-level=1
        --ns-durations=[T0H_, T0L_]
    one-signal := rmt.Signals.alternating
        --resolution=RESOLUTION_
        --first-level=1
        --ns-durations=[T1H_, T1L_]
    // Terminate every frame with the reset interval, so that consecutive
    // writes are separated. Use one item of two low halves, since a single
    // signal would be padded with an end marker.
    reset-signal := rmt.Signals 2 --resolution=RESOLUTION_
    reset-signal.set 0 --ns=(RESET_ / 2) --level=0
    reset-signal.set 1 --ns=(RESET_ / 2) --level=0
    encoder_ = rmt.Encoder --msb --stop=reset-signal {
      0: zero-signal,
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
