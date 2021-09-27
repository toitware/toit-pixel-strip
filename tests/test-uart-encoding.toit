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
