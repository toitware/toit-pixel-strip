// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
import pixel_strip show PixelStrip
import uart
import system
import i2s
import math
import monitor
import gpio
import net
import net.udp

/**
ESP32 peer for the PIO pixel-strip capture fixture.

Uses ESP22 for output, ESP4/34 for UART coordination, and optional I2S receive
  load on ESP13/14/32. Only the documented WROOM rig is supported.
*/

main:
  control := uart.Port --tx=4 --rx=34 --baud-rate=115_200
  // Reset the capture board only after the coordination UART is listening.
  run := gpio.Pin 21 --output --open-drain --value=1
  try:
    run.set 0
    sleep --ms=100
    run.set 1
  finally:
    run.close
  print "pixel-peer: ready"
  try:
    while true:
      line := read-line control
      print "pixel-peer: $line"
      // A reset while RX is listening can prefix the handshake with a NUL.
      if line.ends-with "PIXEL-CAPTURE":
        send-line control "HELLO"
        continue
      if line == "QUIT": return
      parts := line.split " "
      if parts.size != 6 or parts[0] != "CASE": continue
      mode := parts[1]
      count := int.parse parts[2]
      seed := int.parse parts[3]
      loaded := parts[4] == "1"
      frames := int.parse parts[5]
      strip := make-strip mode count
      frame := ByteArray count * 3: pattern it seed
      busy := Load loaded
      try:
        // Allow constructor-related edges to settle before capture is armed.
        sleep --ms=10
        send-line control "READY"
        if (read-line control) != "GO": throw "bad coordination"
        started := Time.monotonic-us
        frames.repeat: |frame-index|
          // Reuse the caller's storage with different contents, as an animation
          // does. This catches stale DMA data and premature output completion.
          frame.size.repeat: frame[it] = pattern it ((seed + frame-index) % 4)
          strip.output-interleaved frame
          // UART owns its reset interval; immediately prepare the next frame.
          // Other backends retain the caller's documented spacing requirement.
          if mode != "uart": sleep --ms=3
        // Closing directly after the final queued frame must drain it completely.
        if mode == "uart": strip.close
        print "pixel-peer: emitted $frames frames in $(Time.monotonic-us - started) us"
        send-line control "DONE"
        if (read-line control) != "NEXT": throw "bad coordination"
      finally:
        busy.close
        strip.close
  finally:
    control.close

make-strip mode/string count/int:
  if mode == "rmt4x1": return ParallelStrips count 4
  if mode == "rmt8x1": return ParallelStrips count 8
  if mode == "uart": return PixelStrip.uart count --pin=22
  if mode == "rmt1": return PixelStrip.rmt count --pin=22 --memory-block-count=1
  if mode == "rmt": return PixelStrip.rmt count --pin=22
  return PixelStrip.i2s count --pin=22

// All these ESP pins connect to RP inputs and avoid the coordination UART,
// reset/boot lines and the I2S receive workload. RP32 observes ESP22.
class ParallelStrips:
  strips_/List ::= []

  constructor count/int channels/int:
    pins := [22, 19, 27, 18, 23, 33, 25, 26]
    success := false
    try:
      channels.repeat:
        strips_.add (PixelStrip.rmt count --pin=pins[it] --memory-block-count=1)
      success = true
    finally:
      if not success: close

  output-interleaved frame/ByteArray:
    done := []
    errors := []
    strips_.do: |strip|
      finished := monitor.Latch
      done.add finished
      task::
        try:
          error := catch: strip.output-interleaved frame
          if error: errors.add error
        finally:
          critical-do: finished.set true
    done.do: it.get
    if not errors.is-empty: throw errors.first

  close:
    strips_.do: it.close
    strips_.clear

class Load:
  running_/bool := true
  tasks_/List ::= []
  finished_/List ::= []
  input_/i2s.Bus? := null
  network_/net.Client? := null
  socket_/udp.Socket? := null
  packets_/int := 0

  constructor enabled/bool:
    if enabled: start_

  start_:
    rendered := monitor.Latch
    finished_.add rendered
    tasks_.add (task::
      try:
        iteration := 0
        while running_:
          // Model frame rendering and audio-feature computation with allocation.
          bytes := ByteArray 4096
          256.repeat: bytes[it] = (math.sin it.to-float * 127 + 128).to-int
          if iteration++ % 16 == 0: system.process-stats --gc
          sleep --ms=5
      finally:
        critical-do: rendered.set true)
    // The music project captures 16 kHz stereo audio. The rig has no codec;
    // clocking an input still exercises I2S DMA and task scheduling.
    input_ = i2s.Bus --master --rx=13 --ws=14 --sck=32
    input_.configure --sample-rate=16_000 --bits-per-sample=16
    input_.start
    received := monitor.Latch
    finished_.add received
    tasks_.add (task::
      try:
        buffer := ByteArray.external 1024
        while running_:
          input_.read buffer
      finally:
        critical-do: received.set true)

    network_ = net.open
    socket_ = network_.udp-open --port=8989
    network-done := monitor.Latch
    finished_.add network-done
    tasks_.add (task::
      try:
        while running_:
          packet := socket_.receive
          socket_.send packet
          packets_++
      finally:
        critical-do: network-done.set true)

  close:
    running_ = false
    tasks_.do: it.cancel
    finished_.do: it.get
    if socket_: socket_.close
    if network_:
      network_.close
      print "pixel-peer: load exchanged $packets_ UDP packets"
    if input_:
      input_.stop
      input_.close
      input_ = null

pattern index/int seed/int -> int:
  if seed == 0: return 0
  if seed == 1: return 255
  if seed == 2: return index % 2 == 0 ? 0x55 : 0xaa
  return (index * 37 + seed * 11) & 255

read-line port/uart.Port -> string:
  return with-timeout --ms=120_000:
    port.in.read-line

send-line port/uart.Port line/string:
  port.out.write "$line\n"
