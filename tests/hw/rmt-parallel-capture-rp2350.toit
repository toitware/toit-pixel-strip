// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import .pixel-capture-rp2350 as capture

main:
  // Observe each output in turn while all eight channels transmit.
  capture.run ["rmt8x1"]
      --pins=[32, 4, 5, 6, 7, 11, 40, 41]
      --counts=[200]
      --seeds=[2, 3]
