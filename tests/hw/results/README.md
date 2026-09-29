# PIO and pixel-strip validation — 2026-09-21

Hardware: WeAct RP2350B `DC67867C6256ED2B` and the existing classic ESP32
`opposite-singer` at 192.168.77.95. Signal ESP22 → RP32; no WROVER involved.
The ESP32 ran this branch's development firmware, SDK
`v2.0.0-alpha.199.16+floitsch-rp2350-support.f5987a52`, with the UART refill fix.

UART sequencing has since changed to prepare → flush previous → 300 us reset
→ queue next. See the [new validation](uart-pipeline/README.md) for the current
implementation and the moved package-local suite. This report records the
earlier implementation.

## Results

| Check | Result |
| --- | --- |
| Assembler generator and metadata | 4 host tests passed |
| Program validation and waveform decoder | Both Toit host tests passed |
| Pixel-strip UART encoding | Existing package test passed |
| PIO contracts, lifetime, GC and GPIO regression | Passed on RP2350 |
| Pixel capture pass 1, idle | 24/24 cases, 48 frames |
| Pixel capture pass 1, loaded | 24/24 cases, 48 frames |
| Pixel capture pass 2, idle | 24/24 cases, 48 frames |
| Pixel capture pass 2, loaded | 24/24 cases, 48 frames |
| Changing-frame pass, idle | 24/24 cases, 48 frames |
| Changing-frame pass, loaded | 24/24 cases, 48 frames |

Each pass covers UART/RMT/I2S, 20/200 LEDs and four byte patterns. RMT uses
four memory blocks. The subsequent [one-block investigation](rmt-one-block/README.md)
records separate experiments; its failures are not part of these passing runs. Loaded cases
run rendering-like floating-point computation, allocation/GC, 16 kHz stereo
I2S reception and UDP echo. All 48 loaded cases exchanged network data:
93–337 packets per case, 8,699 packets total according to the ESP32. Host
counts can differ because they also include traffic just outside case timing.
The two host generators overlapped during part of the repeat pass.

The additional changing-frame pass mutates and reuses the caller's buffer
between successive outputs. All 96 frames passed, bringing the total to 288.
Its 24 loaded cases exchanged 3,785 packets, 97–187 per case, with one host
generator. The longest pair of output calls plus caller delays took 128.2 ms;
both complete frames still fit the capture window measured from the first edge.

The final PIO contract test includes movable heap buffers while DMA is stalled,
32 KiB transfers with GC, ownership consumption and copy fallback, partial
cancellation with zeroed unread tails, repeated pending-DMA close, waking a
blocked waiter, finalization of an orphaned transfer, all twelve state machines,
instruction sharing, GP34 loopback, pin reservation and IRQ/reset. The existing
GPIO interrupt test also passed 100 transitions after PIO released GP34.

## Bugs reproduced and changes verified

* **UART:** consecutive 200-LED updates merged into one 1,200-byte frame even
  with a 3 ms caller pause. The package now flushes the UART before returning.
  Captures also showed 10–17.4 us inter-bit gaps. The native UART writer now
  reapplies a half-FIFO refill threshold after each high-speed IDF write;
  IDF otherwise restores its ten-byte threshold on every write.
* **I2S:** the next output restarted DMA before a 200-LED frame finished.
  Captured first frames contained approximately 373–453 bytes instead of 600.
  The package now waits for wire time plus a reset margin before stopping.
* **RMT:** the one-block default intermittently corrupted 200-LED frames,
  including mismatches at byte 100 and byte 132. Classic ESP32 now defaults
  to four blocks. Other architectures retain the previous one-block default;
  explicit caller choices remain supported.

The load fixture's worker cancellation and UART reset synchronization were
fixed separately. A 26.2 ms capture was too short under load: measured output
calls plus caller delays reached 105.6 ms. Loaded captures now cover 104.9 ms
starting at the first physical rising edge, and captured both complete frames
in every final case. Idle captures retain the 26.2 ms window.

The PIO audit also found that closing a transfer could deadlock behind a
concurrent `take-buffer` waiting for more DMA input. Close now requests
cancellation before acquiring the reclamation mutex. The contract fixture
includes this case, plus direct allocating reads and word I/O.

## Scope audit

* `.pio` is the first program format. Generated immutable `Program` objects
  leave room for a later builder or compiler; neither is required for this phase.
* The lifecycle follows the ULP separation of program description, loading
  and execution. PIO data travels through FIFO/DMA instead of shared RTC memory.
* Bulk writes copy by default; allocating reads return external arrays.
  `--no-copy` explicitly opts into consumption, with copying fallback for
  unsuitable storage. DMA never retains movable heap pointers.
* Primitive inspection and stalled-DMA task tests cover the nonblocking
  requirement. Cancellation is requested asynchronously, and storage remains
  owned until hardware has stopped.
* Tests cover allocation, GPIO ownership, IRQs, GC, cancellation and teardown,
  plus the three pixel-strip backends idle and under computation, allocation,
  audio DMA and network load on the connected WROOM ESP32.
* The user will supply WROVER hardware for the next phase; PSRAM validation
  remains outside this completed hardware scope.

These are digital captures with 100 ns resolution, not a test of LED power,
level shifting or every WS2812/SK6812 revision's timing limits. WROVER/PSRAM,
RGBW and other ESP32 variants remain untested here.

## Artifacts and device state

The adjacent text files contain complete final logs. Baseline diagnostic logs
and test firmware are also retained locally in `build/pio-results/` (ignored
build artifacts). `firmware-sha256.txt` identifies the tested images.

The RP2350 ends with its successful contract-test image (version 107); its OTA
service remains available. The ESP32 has the development firmware with the
UART fix and no running pixel test. To use the matching local Jaguar build:

```sh
JAG_TOIT_REPO_PATH="$PWD" \
  TOIT_PACKAGE_CACHE_PATHS="$PWD/tools/.packages-bootstrap" \
  build/pio-jag/jag run ../toit-pixel-strip/tests/hw/peer.toit \
  --device opposite-singer
```

Activate the capture firmware before that command when taking more captures.
The ordinary installed Jaguar still targets the stock alpha.199 SDK.

The fixtures and reports have since moved into this package’s `tests/hw/`.
See [the current workflow](../README.md). Historical logs retain original paths.
