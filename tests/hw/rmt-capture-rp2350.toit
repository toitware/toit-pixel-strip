// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import .pixel-capture-rp2350 as capture

main:
  capture.run ["rmt1"] --rounds=4
