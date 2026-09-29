// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import io

/** Decodes a 10 MHz single-pin PIO capture into WS2812 frames and diagnostics. */
class Capture:
  frames/List ::= []
  errors/List ::= []
  high-min/int := 1000
  high-max/int := 0
  low-max/int := 0
  reset-min/int := 1 << 30
  frame_/ByteArray ::= ByteArray 4096
  bits_/int := 0
  value_/int := 0
  run_/int := 0
  previous_/int := 0
  have-high_/bool := false

  constructor samples/ByteArray:
    (samples.size / 4).repeat: |word-index|
      word := io.LITTLE-ENDIAN.uint32 samples word-index * 4
      32.repeat: |bit-index|
        bit := (word >> (31 - bit-index)) & 1
        if bit == previous_:
          run_++
        else:
          transition_ bit
    if previous_ == 1:
      errors.add "capture ended during high pulse"
    else if run_ >= 500:
      finish-frame_
    else if bits_ != 0:
      errors.add "capture ended before reset"

  transition_ bit/int:
    if previous_ == 1:
      have-high_ = true
      high-min = min high-min run_
      high-max = max high-max run_
      if run_ < 2 or run_ > 10:
        if errors.size < 10: errors.add "high pulse $(run_ * 100) ns at bit $bits_"
      value_ = (value_ << 1) | (run_ >= 6 ? 1 : 0)
      bits_++
      if bits_ % 8 == 0:
        if bits_ / 8 <= frame_.size:
          frame_[bits_ / 8 - 1] = value_ & 255
        else if errors.size < 10:
          errors.add "frame exceeds decoder capacity"
    else if have-high_:
      if run_ >= 500:
        reset-min = min reset-min run_
        finish-frame_
      else:
        low-max = max low-max run_
        if run_ > 16 and errors.size < 10:
          errors.add "inter-bit low $(run_ * 100) ns at bit $bits_"
    previous_ = bit
    run_ = 1

  finish-frame_:
    if bits_ == 0: return
    if bits_ % 8 != 0: errors.add "frame has $bits_ bits"
    frames.add (frame_.copy 0 (min frame_.size (bits_ / 8)))
    bits_ = 0
    value_ = 0
