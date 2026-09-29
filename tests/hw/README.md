# Pixel-strip hardware tests

These tests are manual. They live under `tests/hw/` so package test discovery
in the Toit SDK does not automatically run them. The existing host UART
encoding test stays under `tests/`. All package imports resolve to this checkout;
no sibling SDK source-tree imports are required by the fixtures.

## Rig and requirements

The measured rig is a classic WROOM ESP32 (`opposite-singer`, 192.168.77.95)
and a WeAct RP2350B. ESP22 drives RP32. Coordination is ESP4 → RP1 and
RP16 → ESP34; ESP21 open-drain drives RP RUN. Both boards share ground.
The peer resets the capture board after opening its coordination UART.
The optional audio load uses ESP13/14/32 and must not share the pixel output.

Use an SDK with the RP2350 PIO library and the ESP32 high-speed UART refill fix.
The ESP32 firmware and Jaguar compiler must use matching SDK versions.
The RP2350 must run `pixel-capture-rp2350.toit` as its boot application.
With the development SDK checkout in `$SDK_REPO`, set
`TOIT_RP2350_PROGRAM` to the absolute path of this package's capture entry point
when configuring `$SDK_REPO/toolchains/rp2350`. Follow that SDK's
`docs/rp2350.md` build and OTA instructions. Allow OTA to activate the staged
image before the peer resets the RP2350; a hardware reset alone does not
activate a staged image.

## Running

From the package root, start a serial recorder for each board, then a network
load generator, then the ESP32 peer. Serial recording requires Python pyserial.
For example, in separate terminals:

```sh
python3 tests/hw/record-serial.py --port /dev/serial/by-id/RP2350 --seconds 600 \
  --until 'pixel-capture-rp2350: DONE' > rp2350.log
python3 tests/hw/record-serial.py --port /dev/serial/by-id/ESP32 --seconds 600 > esp32.log
python3 tests/hw/network-load.py 192.168.77.95 --seconds 600 > network.log
jag run tests/hw/peer.toit --device opposite-singer
```

Replace the serial paths with the board identifiers. When using the local
Jaguar development build from the SDK checkout, the final command is:

```sh
JAG_TOIT_REPO_PATH="$SDK_REPO" \
  TOIT_PACKAGE_CACHE_PATHS="$SDK_REPO/tools/.packages-bootstrap" \
  "$SDK_REPO/build/pio-jag/jag" run tests/hw/peer.toit --device opposite-singer
```

A successful run ends with `pixel-capture-rp2350: DONE failures=0`. Keep both
board logs and the network log. Stop the host load generator after the capture.

## Coverage

| RP2350 boot program | Cases | Purpose |
| --- | ---: | --- |
| `pixel-capture-rp2350.toit` | 48 | UART/RMT/I2S, 20/200 LEDs, four patterns, idle/loaded |
| `uart-capture-rp2350.toit` | 96 | UART, 1/20/200 LEDs, four patterns, idle/loaded, four rounds |
| `rmt-capture-rp2350.toit` | 64 | Force one RMT block, four rounds of the RMT matrix |
| `rmt-parallel-capture-rp2350.toit` | 32 | Eight concurrent one-block strips, observing each output in turn; hardware validation pending |

Every case compares two complete frames with different contents, reusing the
caller buffer. UART has no caller sleep between frames, must leave at least
300 us low between frames, and closes immediately after queuing the last frame.
This checks both reset handling and draining on close. RMT and I2S retain the
3 ms caller pause. RMT uses the package default unless explicitly testing one
block. The one-block experiments are known to fail on the current classic ESP32
backend; see [the investigation](results/rmt-one-block/README.md).

PIO captures have 100 ns resolution, covering 52.4 ms idle and 104.9 ms loaded
from the first rising edge. The trigger shortens the first pulse. `high`,
`low-max`, and `reset-min` diagnostics are in 100 ns ticks. Distinguish a capture
window overrun from a truncated transmission. The decoder separates frames
at 50 us, then the UART test independently checks its stricter 300 us reset.

Load consists of rendering-like floating-point work, allocation/GC, 16 kHz
stereo I2S RX and 1 KiB UDP echo on port 8989. The peer reports packet counts
per loaded case. No audio codec is attached; audio sample contents are ignored.
Idle cases still have Wi-Fi connected and can receive host UDP probes.
These are digital wire tests. LED power, level shifting, WROVER/PSRAM, RGBW,
and other ESP32 variants require separate validation.

The parallel fixture requires ESP `[22,19,27,18,23,33,25,26]` connected to RP
`[32,4,5,6,7,11,40,41]`. All RP signal pins remain inputs.

## Standalone checks

```sh
toit run tests/test-uart-encoding.toit
toit run tests/hw/ws2812-test.toit
jag run tests/hw/load-test.toit --device opposite-singer
jag run tests/hw/rmt-encoder-esp32.toit --device opposite-singer
```

The load lifecycle test runs without the RP2350 peer. The RMT encoder test uses
internal loopback on ESP23 to check MSB/LSB order, partial bytes and
start/between/stop patterns. Run it separately from the pixel peer.

`capture-program.pio` and its generated `capture-program.toit` are checked in.
To regenerate with the SDK's assembler wrapper:

```sh
python3 "$SDK_REPO/tools/pio/compile.py" tests/hw/capture-program.pio \
  --pioasm "$SDK_REPO/build/pioasm/pioasm" -o /tmp/capture-program.toit
```

Copy the generated program declaration into `capture-program.toit`, retaining
its package-relative license header. The generated declaration is checked
against the assembler during development. Prior logs and reports are under
[results](results/README.md); their firmware paths identify historical artifacts
in the SDK build directory.
