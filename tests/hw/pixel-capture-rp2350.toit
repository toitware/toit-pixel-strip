// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import rp2350.pio
import uart
import .capture-program show CAPTURE-PROGRAM
import .ws2812 show Capture

main:
  run ["uart", "rmt", "i2s"]

run modes/List --rounds/int=1 --pins/List=[32] --counts/List=[20, 200] --seeds/List=[0, 1, 2, 3]:
  sleep --ms=2000
  control := uart.Port --tx=16 --rx=1 --baud-rate=115_200
  failures := 0
  try:
    control.out.write "\nPIXEL-CAPTURE\n"
    if (read-line control) != "HELLO": throw "missing peer"
    pins.do: |pin/int|
      sm := pio.StateMachine CAPTURE-PROGRAM --frequency=10_000_000 --in-pins=[pin]
      try:
        rounds.repeat:
          [false, true].do: |load/bool|
            modes.do: |mode/string|
              counts.do: |pixels/int|
                seeds.do: |seed/int|
                  command := "CASE $mode $pixels $seed $(load ? 1 : 0) 2"
                  control.out.write "$command\n"
                  if (read-line control) != "READY": throw "peer not ready"
                  sm.reset
                  rx := sm.submit-read (ByteArray.external (load ? 131_072 : 65_536)) --no-copy
                  try:
                    sm.start
                    control.out.write "GO\n"
                    samples := with-timeout --ms=5000: rx.take-buffer
                    sm.pause
                    if (read-line control) != "DONE": throw "peer not done"
                    capture := Capture samples
                    errors := capture.errors
                    if capture.frames.size != 2: errors.add "expected 2 frames, got $(capture.frames.size)"
                    if mode == "uart" and capture.reset-min < 3000:
                      errors.add "reset interval $(capture.reset-min * 100) ns is below 300 us"
                    capture.frames.size.repeat: |index|
                      expected := ByteArray pixels * 3: pattern it ((seed + index) % 4)
                      actual/ByteArray := capture.frames[index]
                      if actual != expected:
                        at := 0
                        while at < (min actual.size expected.size) and actual[at] == expected[at]: at++
                        errors.add "frame $index size=$(actual.size) first-mismatch=$at actual=$(actual[at..(min actual.size at + 8)]) expected=$(expected[(min at expected.size)..(min expected.size at + 8)])"
                    if not errors.is-empty: failures++
                    print "$command: $(errors.is-empty ? "PASS" : "FAIL") pin=$pin high=$(capture.high-min)..$(capture.high-max) low-max=$(capture.low-max) reset-min=$(capture.reset-min) errors=$errors"
                  finally:
                    rx.close
                    sm.pause
                    control.out.write "NEXT\n"
      finally:
        sm.close
    control.out.write "QUIT\n"
    print "pixel-capture-rp2350: DONE failures=$failures"
  finally:
    control.close

pattern index/int seed/int -> int:
  if seed == 0: return 0
  if seed == 1: return 255
  if seed == 2: return index % 2 == 0 ? 0x55 : 0xaa
  return (index * 37 + seed * 11) & 255

read-line port/uart.Port -> string:
  return with-timeout --ms=120_000:
    port.in.read-line
