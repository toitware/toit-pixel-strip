// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import pixel_strip show *
import pixel_strip.uart show *

// Test that the Uart code correctly encodes binary data in
// the high-low pattern that the pixel protocol requires.

class UartTestPixelStrip extends UartEncodingPixelStrip_:

  constructor pixels/int --bytes_per_pixel/int:
    super pixels --bytes_per_pixel=bytes_per_pixel

  output_interleaved interleaved_data/ByteArray -> none:
    // We only implemented this method to avoid the abstract class error, it's not used for testing.
    throw "UNREACHABLE"

  close:  // Do nothing.

  is_closed: return false

expect_uart_equals interleaved/ByteArray array/ByteArray:
  encoding := create_high_low_encoding interleaved
  // 3 bits encoded in each byte.
  bits_encoded := array.size * 3

  // We expect the total number of bits encoded to be a whole byte.
  expect bits_encoded % 8 == 0

  // We expect each bit to be encoded by three characters (HLL or HHL).
  expect_equals encoding.size / 3 bits_encoded

  for i := 0; i < bits_encoded; i += 3:
    byte := array[i / 3]
    first_bits :=  (byte & 0b00_000_11) >> 0  // Uart transmits low bits first.
    middle_bits := (byte & 0b00_111_00) >> 2
    last_bits :=   (byte & 0b11_000_00) >> 5  // Uart transmits high bits last.
    first_s :=  encoding[i * 3 + 0..i * 3 + 3]
    middle_s := encoding[i * 3 + 3..i * 3 + 6]
    last_s :=   encoding[i * 3 + 6..i * 3 + 9]
    if first_s == "HLL":
      expect_equals 0b11 first_bits     // Start bit is H after inversion, then we have LL (11 before inversion).
    else if first_s == "HHL":
      expect_equals 0b10 first_bits     // Start bit is H after inversion, then we have HL (01 before inversion, little endian order).
    else:
      throw "Malformed expectation: $first_s"
    if middle_s == "HLL":
      expect_equals 0b110 middle_bits   // Little endian order, HLL after inversion.
    else if middle_s == "HHL":
      expect_equals 0b100 middle_bits   // Little endian order, HHL after inversion.
    else:
      throw "Malformed expectation: $middle_s"
    if last_s == "HLL":
      expect_equals 0b10 last_bits      // HL after inversion, little endian order, then the stop bit is L after inversion.
    else if last_s == "HHL":
      expect_equals 0b00 last_bits      // HH after inversion, then the stop bit is L after inversion.
    else:
      throw "Malformed expectation: $last_s"

create_high_low_encoding ba/ByteArray:
  result := ""
  ba.do: | byte |
    for i := 7; i >= 0; i--:  // Bits in pixel protocol must be sent big-endian first.
      bit := (byte >> i) & 1
      result += ["HLL", "HHL"][bit]  // Encode 0 as High-Low-Low and 1 and High-High-Low.
  return result

main:
  encoding_test
  rounding_test

encoding_test:
  one_pix := UartTestPixelStrip 1 --bytes_per_pixel=3

  three_zeros := #[0, 0, 0]
  one_pix.output_interleaved_ three_zeros:
    expect_uart_equals
      three_zeros
      it
    it.size

  all_ones := #[0xff, 0xff, 0xff]
  one_pix.output_interleaved_ all_ones:
    expect_uart_equals
      all_ones
      it
    it.size

  random_bytes := #[41, 103, 243]
  one_pix.output_interleaved_ random_bytes:
    expect_uart_equals
      random_bytes
      it
    it.size

  many_pix := UartTestPixelStrip 255 / 3 --bytes_per_pixel=3

  long_sequence := ByteArray 255: it
  many_pix.output_interleaved_ long_sequence:
    expect_uart_equals
      long_sequence
      it
    it.size

class UartTestPixelStripRounding extends UartEncodingPixelStrip_:

  constructor pixels/int --bytes_per_pixel/int:
    super pixels --bytes_per_pixel=bytes_per_pixel

  output_interleaved interleaved_data/ByteArray -> none:
    expect interleaved_data.size == pixels_ * 4  // 4 bytes per pixel.
    last_idx := (pixels_ - 1) * 4
    last_idx.repeat: expect_equals 0 interleaved_data[it]  // All but last pixel are zero.
    // GRBW ordering.
    expect_equals 0xaa interleaved_data[last_idx + 0]
    expect_equals 0x55 interleaved_data[last_idx + 1]
    expect_equals 42   interleaved_data[last_idx + 2]
    expect_equals 0xff interleaved_data[last_idx + 3]

    output_interleaved_ interleaved_data: | uart_output |
      // Four bytes per pixel.
      unencoded_byte_count := pixels_ * 4  // 44 for an 11 pixel strip.
      // Round up to 3.
      rounded_unencoded_byte_count := round_up unencoded_byte_count 3  // 45 for an 11 pixel strip.
      // 8 bits in a byte.
      unencoded_bit_count := rounded_unencoded_byte_count * 8 // 360 for an 11 pixel strip.
      // The UART encodes 3 bits in each output byte.
      encoded_byte_count := unencoded_bit_count / 3  // 120 for an 11 pixel strip.

      expect_equals encoded_byte_count uart_output.size  // 120 for an 11 pixel strip.

      // The number of bits the pixels will read (the rest fall off the end of the strip).
      number_of_real_bits := pixels_ * 4 * 8
      number_of_real_bits_rounded := round_up number_of_real_bits 3
      number_of_real_output_bytes := number_of_real_bits_rounded / 3
      number_of_real_output_bytes.repeat:
        // 0 is never valid encoding of the high-low patterns.
        expect uart_output[it] != 0

      // After the encoding of 3 bits to bytes, 000 is encoded as 0x5b and 111
      // is encoded as 0x12.
      // We expect 0x12 for the penultimate encoded byte since it must be
      // somewhere in the last unencoded byte, which was all-ones (the white
      // component of the last pixel is 0xff).
      expect_equals 0x12 uart_output[number_of_real_output_bytes - 2]

      // Return value from block.
      uart_output.size

  close: // Do nothing

  is_closed: return false

rounding_test:
  // Try some 4-byte-per-pixel strips that are not a multiple of 3 in
  // length.  This checks that we round things correctly when fractional
  // bytes are output at the end because of the 3-bit-to-8-bit encoding.
  for length := 9; length < 12; length++:
    test_strip := UartTestPixelStripRounding length --bytes_per_pixel=4

    r := ByteArray length
    g := ByteArray length
    b := ByteArray length
    w := ByteArray length

    r[length - 1] = 0x55
    g[length - 1] = 0xaa
    b[length - 1] = 42
    w[length - 1] = 0xff

    test_strip.output r g b w
