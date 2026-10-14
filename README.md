# Pixel Strip

A driver library for WS2812B- and SK8612-compatible LED pixel strips like Neopixels.

This takes care of the communication with the pixels via a 1-wire
timing-based protocol.

To use it, you need to feed byte-arrays of red, green and blue pixel
data to the strips.

The I2S backend requires the SDK's ESP-IDF I2S TX underrun fix
([esp-idf#136](https://github.com/toitware/esp-idf/pull/136)). It keeps the bus
running between frames and drains pending output when closed. The minimum SDK
version is set to the upcoming v2.0.0-alpha.200 release; the released alpha.199
firmware does not contain the fix. Development firmware must include the fix
as well.

## Example

```
import bitmap show bytemap_zap
import pixel_strip show UartPixelStrip

PIXELS ::= 64  // Number of pixels on the strip.

main:
  pixels := UartPixelStrip PIXELS
    --pin=17  // Output pin - this is the normal pin for UART 2.

  r := ByteArray PIXELS
  g := ByteArray PIXELS
  b := ByteArray PIXELS

  // Paint all pixels with #4480ff.
  r.fill 0x44
  g.fill 0x80
  b.fill 0xff

  pixels.output r g b

  // Here we don't really need it, but in tight animation loops you must
  // occasionally sleep, to avoid triggering the watchdog.
  sleep --ms=1
```
