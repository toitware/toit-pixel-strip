// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import .peer show Load
main:
  3.repeat:
    print "load-test: start $it"
    load := Load true
    sleep --ms=250
    load.close
    print "load-test: closed $it"
  print "load-test: PASS"
