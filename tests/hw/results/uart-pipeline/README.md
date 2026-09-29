# Deferred UART flush and package-local tests — 2026-09-22

Hardware: classic WROOM ESP32 `opposite-singer` (192.168.77.95) and WeAct
RP2350B `DC67867C6256ED2B`, ESP22 → RP32. The ESP32 retains the development
firmware with the high-speed UART refill fix; no native change was needed
for this UART sequencing change.

## Implementation

UART output now encodes the next frame before flushing the previous frame,
then busy-waits in Toit until `Time.monotonic-us` has advanced at least 300 us,
and queues the encoded frame without a trailing flush. The UART driver copies
the encoded data, allowing caller and encoding buffers to be reused while
transmission continues. Large writes can still yield for driver buffer space.
`close` flushes pending output before releasing the port, with cleanup in a
`finally` block. The busy-wait does not block a native primitive; scheduling or
GC may extend the reset interval.

The fixtures, waveform decoder, generated capture program, serial/network
helpers, RMT experiments and historical results now live in this package's
`tests/hw/`. The SDK's PIO program/assembler/contract tests remain in the SDK.
The SDK external-package runner globs only test entry points directly under
`tests/`; this hardware suite is manual. See [the workflow](../../README.md).

## Validation

* Source analysis, the existing UART encoding test and the relocated waveform
  decoder host test passed.
* The package capture program matches its `.pio` source when assembled by the
  SDK's `tools/pio/compile.py`. SDK PIO program and assembler tests passed after
  removing the package-specific tests from the SDK tree.
* UART/RMT/I2S: **48/48 cases, 96 frames passed**, idle and loaded, 20/200 LEDs,
  four initial patterns and changing frame contents.
* The relocated RMT encoder and load-lifecycle fixtures passed separately on
  the ESP32; their output follows the full matrix in `all-backends-esp.txt`.
* UART stress: **96/96 cases, 192 frames passed**, four rounds of 1/20/200
  LEDs, four initial patterns, idle and loaded. The minimum measured reset
  interval was 744.8 us. All 48 loaded cases exchanged UDP data
  (101–204 packets per case, 7818 total); the host confirmed the same echo count.

The two final matrices total **144 passing cases and 288 correct frames**,
including 224 UART frames. All UART inter-frame reset intervals exceeded
300 us; the minimum across both final runs was 665.7 us.

Unlike the earlier validation, UART has no caller sleep between frames. It
reuses the same caller buffer with changed data, verifies at least 300 us of
physical low time between frames, and closes immediately after queuing the
last frame. The shortest UART reset interval in the full matrix was 665.7 us.
All 24 loaded matrix cases exchanged UDP data (102–213 packets per case,
4000 packets total). Rendering-like computation, allocation/GC and 16 kHz
stereo I2S RX run concurrently. Idle cases still have Wi-Fi connected.

The initial full-matrix run passed every UART case but cut off one idle I2S
capture at the old 26.2 ms window. That case's two output calls plus caller
pauses took 38.6 ms. The idle capture window was increased to 52.4 ms, retaining
104.9 ms under load, and all 48 cases passed on rerun. Both initial logs are
retained with `initial-short-window-` names. A timeout printed before their
first reset belongs to the capture app waiting for a peer before deployment;
the subsequent peer reset starts the measured run.

These are digital wire measurements at 100 ns resolution, not physical LED
power or level-shifting tests. WROVER/PSRAM, RGBW and other ESP32 variants
remain untested. The older one-block RMT failures remain a separate known
limitation; the full matrix uses the package's four-block ESP32 default.

## Artifacts

The adjacent logs contain physical capture results and peer workload counts.
Firmware hashes and final test-source hashes are recorded alongside them.
Test firmware snapshots remain in the SDK checkout's ignored
`build/pio-results/` directory.

The RP2350 is restored to the PIO contract-test image (version 107). The ESP32
retains its known-good development firmware; the transient pixel peer exits
on completion. Serial recorders and the network load generator are stopped. The restored PIO
contract and GPIO interrupt checks passed again (`restored-pio-contracts.txt`).

The source hashes identify the hardware-tested source. During PR preparation,
the generated capture program’s extra trailing blank line was removed; its
instructions and configuration are unchanged. Serial logs are preserved verbatim.
