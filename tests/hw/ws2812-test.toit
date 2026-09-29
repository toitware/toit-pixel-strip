// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import expect show *
import io
import .ws2812 show Capture

main:
  expected := #[0, 255, 0x55, 0xaa, 17, 128]
  bits := []
  2.repeat:
    expected.do: |byte/int|
      8.repeat: |index|
        high := byte & (1 << (7 - index)) != 0 ? 8 : 4
        high.repeat: bits.add 1
        (12 - high).repeat: bits.add 0
    1000.repeat: bits.add 0
  samples := ByteArray (round-up bits.size 32) / 8
  bits.size.repeat: |index|
    if bits[index] == 0: continue.repeat
    offset := (index / 32) * 4
    word := io.LITTLE-ENDIAN.uint32 samples offset
    io.LITTLE-ENDIAN.put-uint32 samples offset word | (1 << (31 - index % 32))
  capture := Capture samples
  expect-equals [] capture.errors
  expect-equals 2 capture.frames.size
  capture.frames.do: expect-equals expected it
  expect-equals 4 capture.high-min
  expect-equals 8 capture.high-max
