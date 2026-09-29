// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license in LICENSE.
// Generated from capture-program.pio by the SDK's tools/pio/compile.py.
import rp2350.pio

CAPTURE-PROGRAM ::= pio.Program [
  0x20a0,  // wait   1 pin, 0
  0x4001,  // in     pins, 1
]
    --origin=-1
    --pio-version=1
    --used-gpio-ranges=0
    --wrap-target=1
    --wrap=1
    --in-count=1
    --in-shift=pio.SHIFT-LEFT
    --auto-push
    --push-threshold=32
    --fifo=2
