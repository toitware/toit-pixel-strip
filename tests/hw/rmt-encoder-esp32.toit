// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import expect show *
import rmt

// Internal RMT loopback on ESP23 (RP7 remains an input).
main:
  channels := rmt.ChannelInOut 23 --resolution=1_000_000
  zero := rmt.Signals.alternating --resolution=1_000_000 --first-level=1 --ns-durations=[10_000, 10_000]
  one := rmt.Signals.alternating --resolution=1_000_000 --first-level=1 --ns-durations=[20_000, 10_000]
  marker := rmt.Signals.alternating --resolution=1_000_000 --first-level=1 --ns-durations=[30_000, 10_000]
  data := #[0x96, 0x3b]
  try:
    [false, true].do: |msb/bool|
      [false, true].do: |decorated/bool|
        encoder := rmt.Encoder
            --msb=msb
            --start=(decorated ? marker : null)
            --between=(decorated ? marker : null)
            --stop=(decorated ? marker : null)
            {0: zero, 1: one}
        try:
          [1, 7, 8, 9, 16].do: |bits/int|
            expected := []
            if decorated: expected.add 30
            bits.repeat: |index|
              if decorated and index > 0 and index % 8 == 0: expected.add 30
              shift := msb ? 7 - index % 8 : index % 8
              expected.add ((data[index / 8] >> shift) & 1 == 0 ? 10 : 20)
            if decorated: expected.add 30
            channels.in.start-reading --min-ns=100 --max-ns=50_000
            channels.out.write data[..((bits + 7) / 8)] --encoder=encoder --bit-size=bits
            actual := with-timeout --ms=1000: channels.in.wait-for-data
            expect-equals expected.size * 2 actual.size
            expected.size.repeat: |index|
              expect-equals 1 (actual.level (index * 2))
              expect ((actual.period (index * 2)) - expected[index]).abs <= 2
              expect-equals 0 (actual.level (index * 2 + 1))
              if index < expected.size - 1:
                expect ((actual.period (index * 2 + 1)) - 10).abs <= 2
        finally:
          encoder.close
  finally:
    channels.close
  print "rmt-encoder-esp32: PASS"
