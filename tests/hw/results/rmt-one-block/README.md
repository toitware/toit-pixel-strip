# One-block RMT investigation — 2026-09-22

The existing WROOM ESP32 (`opposite-singer`, 192.168.77.95) drives ESP22,
observed independently by the RP2350 on GP32. No WROVER or PSRAM was tested.
All cases explicitly request one RMT memory block. The package's four-block
classic-ESP32 default is unchanged by this investigation.

**Outcome:** none of the tested configurations made one-block output reliable.
The final uninstrumented combination also failed. Keep the four-block
workaround for the measured workload while investigating native interrupt
latency further; this is not a demonstrated one-block fix.

## Method

`rmt-capture-rp2350.toit` repeats the pixel capture matrix four times:
20/200 RGB LEDs, four initial patterns, idle/loaded, two changing frames per
case. A full run is 64 cases and 128 frames. A case fails if either frame has
wrong bytes, length, frame count, or decoder errors. The RP2350 samples the
physical signal at 10 MHz. Load is the same rendering/allocation/GC, I2S RX
and UDP echo workload used in the earlier validation. "Idle" means those
application workers are absent; Wi-Fi remains connected and host UDP probes
still arrive.

These are separate runs of an intermittent failure, not a controlled estimate
of relative failure probabilities. Do not interpret a larger failure count as
proof that an optimization made the driver worse.

## Captured results

| ESP32 implementation | Cases completed | Failed idle | Failed loaded |
| --- | ---: | ---: | ---: |
| Original generic encoder, default priority | 64 | 1 | 6 |
| IDF bytes encoder fast path, default priority | 64 | 5 | 10 |
| Bytes fast path, priority 3 | 60 | 2 | 10 |
| Generic encoder, priority 3, cache-safe ISR | 64 | 2 | 8 |
| Bytes fast path, priority 3, cache-safe ISR, no profiling | 64 | 6 | 13 |

The final combined run completed all 64 cases: 45 passed and 19 failed.
All 32 loaded cases exchanged UDP data (94–172 packets per case).
The combined image used the same bytes path as the instrumented experiment,
without instrumentation or printf, and retained the flash fallback concession
explained below. It did not crash.

Captured corruption includes repeated earlier chunks, altered bytes, and
extra bytes before reset. For example, a baseline loaded 200-LED random frame
first differs at byte 536: its next eight bytes match positions 528–535 instead.
This is consistent with the hardware transmitting stale buffer contents after
a missed refill, rather than a frame boundary problem alone.

The priority-only run was interrupted after 60 cases to run the encoder
regression fixture; it is not a complete matrix. The regression fixture passed
MSB/LSB order, partial-byte lengths, and start/between/stop patterns. Full-byte
binary patterns used the bytes encoder; other patterns retained the generic
fallback. Complete board logs accompany this report.

## Timing evidence

One classic ESP32 RMT block stores 64 symbols. The driver refills one half
while the other half is transmitted: 32 LED bits leave approximately
36.8–41.6 microseconds, depending on bit values, for interrupt response and
refill. More pixels increase the number of opportunities to miss that deadline.

Temporary cycle counters measured the generic encoder at 240 MHz with
priority-3, cache-safe interrupts. Across eight 200-LED frames, the maximum
callback duration in each frame ranged from 27.01 to 37.73 microseconds.
The largest start-to-start interval between refill callbacks was 96.76
microseconds. One of the four captured cases was corrupt. These are elapsed
maxima, including any preemption, not averages or pure CPU costs; callback
start intervals also include the normal time spent transmitting symbols.

The bytes encoder's first profiled frame reported a maximum callback duration
of 3.90 microseconds and a maximum start interval of 47.20 microseconds. That
profiling image then overflowed the EVQ task's stack after printing its
statistics. No complete capture case was returned, so this run provides only
an indicative timing measurement, not reliability evidence. The debug image
also moved the unused generic fallback out of IRAM to fit instrumentation;
it must not be used as production firmware. Logging was outside the ISR.

## Interpretation

We already use the IDF-5 RMT driver. Its generic pattern callback does much more
work per bit than the specialized bytes encoder. Faster encoding is useful,
but the completed comparisons show that faster encoding alone, priority 3
alone with that encoder, and cache-safe priority-3 interrupts with the generic
encoder each still allow corrupt one-block output. Combining all three changes
also failed, so none of those configurations resolves the problem.

The older WLED high-priority backend is a different implementation with a
specialized refill loop and a level-4/5 interrupt shim. A normal IDF priority-3
callback does not have the same interrupt-latency guarantees. Moving to that
approach requires a native backend, careful IRAM/data placement and deferred
completion notification; it is not a package-level timing adjustment. Native
primitives must remain nonblocking. Before choosing a custom ISR, also measure
interrupt core affinity and critical-section delays: channel creation currently
runs directly on whichever Toit scheduler core executes the primitive. Those
variables were not isolated here. The present tests do not prove that a
level-4/5 interrupt is the only possible solution. Several simultaneous strips would require
a separate stress test even after one strip passes.

The prepared `rmt-parallel-capture-rp2350.toit` fixture observes each of eight
outputs in turn while all eight one-block strips transmit concurrently. It
has compiled but has **not** been validated on hardware. No eight-strip
reliability claim is made here.

References: [older WLED high-priority backend](https://github.com/wled/WLED/blob/main/lib/NeoESP32RmtHI/src/NeoEsp32RmtHIMethod.cpp),
[IDF RMT documentation](https://docs.espressif.com/projects/esp-idf/en/v5.4/esp32/api-reference/peripherals/rmt.html).

## Artifacts

Logs and image hashes are in this directory. Experimental firmware and source
snapshots are retained locally in ignored `build/pio-results/`.
`combined-experiment.patch` preserves the native bytes fast path and priority-3
experiment for review; it additionally requires `CONFIG_RMT_ISR_IRAM_SAFE=y`.
The full combined build overflowed IRAM by 16 bytes, so the archived diagnostic
patch moves the unused generic fallback to flash. This is unsuitable for
production use with arbitrary RMT patterns. Instrumentation and experimental
production-source changes were removed after testing.

## Restored device state

After recording results, the boards were restored to ESP32
`esp32-uartfix.envelope` and RP2350
`contracts-v107.bin`, the same known-good images used before this investigation.
The PIO contracts and GPIO interrupt regression passed again after restoration
(`restored-pio-contracts.txt`).
No experimental native RMT or sdkconfig change is retained in the working tree;
the ESP-IDF submodule also has no experimental diff. PIO and UART work from the
preceding task is preserved. Fixture analysis and `git diff --check` pass.
