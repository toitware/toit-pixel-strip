// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import pixel-strip show *
import pixel-strip.uart show *

// Test that the Uart code correctly encodes binary data in
// the high-low pattern that the pixel protocol requires.

class UartTestPixelStrip extends UartEncodingPixelStrip_:

  constructor pixels/int --bytes-per-pixel/int:
    super pixels --bytes-per-pixel=bytes-per-pixel

  output-interleaved interleaved-data/ByteArray -> none:
    // We only implemented this method to avoid the abstract class error, it's not used for testing.
    throw "UNREACHABLE"

  close:  // Do nothing.

  is-closed: return false

expect-uart-equals interleaved/ByteArray array/ByteArray:
  encoding := create-high-low-encoding interleaved
  // 3 bits encoded in each byte.
  bits-encoded := array.size * 3

  // We expect the total number of bits encoded to be a whole byte.
  expect bits-encoded % 8 == 0

  // We expect each bit to be encoded by three characters (HLL or HHL).
  expect-equals encoding.size / 3 bits-encoded

  for i := 0; i < bits-encoded; i += 3:
    byte := array[i / 3]
    first-bits :=  (byte & 0b00_000_11) >> 0  // Uart transmits low bits first.
    middle-bits := (byte & 0b00_111_00) >> 2
    last-bits :=   (byte & 0b11_000_00) >> 5  // Uart transmits high bits last.
    first-s :=  encoding[i * 3 + 0..i * 3 + 3]
    middle-s := encoding[i * 3 + 3..i * 3 + 6]
    last-s :=   encoding[i * 3 + 6..i * 3 + 9]
    if first-s == "HLL":
      expect-equals 0b11 first-bits     // Start bit is H after inversion, then we have LL (11 before inversion).
    else if first-s == "HHL":
      expect-equals 0b10 first-bits     // Start bit is H after inversion, then we have HL (01 before inversion, little endian order).
    else:
      throw "Malformed expectation: $first-s"
    if middle-s == "HLL":
      expect-equals 0b110 middle-bits   // Little endian order, HLL after inversion.
    else if middle-s == "HHL":
      expect-equals 0b100 middle-bits   // Little endian order, HHL after inversion.
    else:
      throw "Malformed expectation: $middle-s"
    if last-s == "HLL":
      expect-equals 0b10 last-bits      // HL after inversion, little endian order, then the stop bit is L after inversion.
    else if last-s == "HHL":
      expect-equals 0b00 last-bits      // HH after inversion, then the stop bit is L after inversion.
    else:
      throw "Malformed expectation: $last-s"

create-high-low-encoding ba/ByteArray:
  result := ""
  ba.do: | byte |
    for i := 7; i >= 0; i--:  // Bits in pixel protocol must be sent big-endian first.
      bit := (byte >> i) & 1
      result += ["HLL", "HHL"][bit]  // Encode 0 as High-Low-Low and 1 and High-High-Low.
  return result

main:
  encoding-test
  rounding-test

encoding-test:
  one-pix := UartTestPixelStrip 1 --bytes-per-pixel=3

  three-zeros := #[0, 0, 0]
  one-pix.output-interleaved_ three-zeros:
    expect-uart-equals
      three-zeros
      it
    it.size

  all-ones := #[0xff, 0xff, 0xff]
  one-pix.output-interleaved_ all-ones:
    expect-uart-equals
      all-ones
      it
    it.size

  random-bytes := #[41, 103, 243]
  one-pix.output-interleaved_ random-bytes:
    expect-uart-equals
      random-bytes
      it
    it.size

  many-pix := UartTestPixelStrip 255 / 3 --bytes-per-pixel=3

  long-sequence := ByteArray 255: it
  many-pix.output-interleaved_ long-sequence:
    expect-uart-equals
      long-sequence
      it
    it.size

class UartTestPixelStripRounding extends UartEncodingPixelStrip_:

  constructor pixels/int --bytes-per-pixel/int:
    super pixels --bytes-per-pixel=bytes-per-pixel

  output-interleaved interleaved-data/ByteArray -> none:
    expect interleaved-data.size == pixels_ * 4  // 4 bytes per pixel.
    last-idx := (pixels_ - 1) * 4
    last-idx.repeat: expect-equals 0 interleaved-data[it]  // All but last pixel are zero.
    // GRBW ordering.
    expect-equals 0xaa interleaved-data[last-idx + 0]
    expect-equals 0x55 interleaved-data[last-idx + 1]
    expect-equals 42   interleaved-data[last-idx + 2]
    expect-equals 0xff interleaved-data[last-idx + 3]

    output-interleaved_ interleaved-data: | uart-output |
      // Four bytes per pixel.
      unencoded-byte-count := pixels_ * 4  // 44 for an 11 pixel strip.
      // Round up to 3.
      rounded-unencoded-byte-count := round-up unencoded-byte-count 3  // 45 for an 11 pixel strip.
      // 8 bits in a byte.
      unencoded-bit-count := rounded-unencoded-byte-count * 8 // 360 for an 11 pixel strip.
      // The UART encodes 3 bits in each output byte.
      encoded-byte-count := unencoded-bit-count / 3  // 120 for an 11 pixel strip.

      expect-equals encoded-byte-count uart-output.size  // 120 for an 11 pixel strip.

      // The number of bits the pixels will read (the rest fall off the end of the strip).
      number-of-real-bits := pixels_ * 4 * 8
      number-of-real-bits-rounded := round-up number-of-real-bits 3
      number-of-real-output-bytes := number-of-real-bits-rounded / 3
      number-of-real-output-bytes.repeat:
        // 0 is never valid encoding of the high-low patterns.
        expect uart-output[it] != 0

      // After the encoding of 3 bits to bytes, 000 is encoded as 0x5b and 111
      // is encoded as 0x12.
      // We expect 0x12 for the penultimate encoded byte since it must be
      // somewhere in the last unencoded byte, which was all-ones (the white
      // component of the last pixel is 0xff).
      expect-equals 0x12 uart-output[number-of-real-output-bytes - 2]

      // Return value from block.
      uart-output.size

  close: // Do nothing

  is-closed: return false

rounding-test:
  // Try some 4-byte-per-pixel strips that are not a multiple of 3 in
  // length.  This checks that we round things correctly when fractional
  // bytes are output at the end because of the 3-bit-to-8-bit encoding.
  for length := 9; length < 12; length++:
    test-strip := UartTestPixelStripRounding length --bytes-per-pixel=4

    r := ByteArray length
    g := ByteArray length
    b := ByteArray length
    w := ByteArray length

    r[length - 1] = 0x55
    g[length - 1] = 0xaa
    b[length - 1] = 42
    w[length - 1] = 0xff

    test-strip.output r g b w
