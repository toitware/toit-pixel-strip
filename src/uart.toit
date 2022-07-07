// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import uart
import bitmap show blit OR
import .pixel_strip

abstract class UartEncodingPixelStrip_ extends PixelStrip:
  out_buf_ := ?
  out_buf_1_ := ?
  out_buf_2_ := ?
  out_buf_3_ := ?
  out_buf_4_ := ?
  out_buf_5_ := ?
  out_buf_6_ := ?
  out_buf_7_ := ?

  constructor pixels/int --bytes_per_pixel/int=3:
    out_buf_ = ByteArray (round_up pixels * bytes_per_pixel 3) * 8 / 3
    out_buf_1_ = out_buf_[1..]
    out_buf_2_ = out_buf_[2..]
    out_buf_3_ = out_buf_[3..]
    out_buf_4_ = out_buf_[4..]
    out_buf_5_ = out_buf_[5..]
    out_buf_6_ = out_buf_[6..]
    out_buf_7_ = out_buf_[7..]

    super pixels --bytes_per_pixel=bytes_per_pixel

  output_interleaved_ interleaved_data/ByteArray [write_block] -> none:
    i0 := interleaved_data
    i1 := (identical i0 inter_) ? inter_1_ : i0[1..]
    i2 := (identical i0 inter_) ? inter_2_ : i0[2..]

    // Split each 24-bit sequence into 8 bytes with 3 bits in each.
    blit i0 out_buf_   1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=5 --mask=0b111
    blit i0 out_buf_1_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=2 --mask=0b111
    blit i0 out_buf_2_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=7 --mask=0b110
    blit i1 out_buf_2_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=7 --mask=0b001 --operation=OR
    blit i1 out_buf_3_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=4 --mask=0b111
    blit i1 out_buf_4_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=1 --mask=0b111
    blit i1 out_buf_5_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=6 --mask=0b100
    blit i2 out_buf_5_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=6 --mask=0b011 --operation=OR
    blit i2 out_buf_6_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=3 --mask=0b111
    blit i2 out_buf_7_ 1 --destination_pixel_stride=8 --source_pixel_stride=3 --shift=0 --mask=0b111

    // In-place translation of the 3 bits into the pixel encoding of those 3 bits.
    blit out_buf_ out_buf_ 8 --lookup_table=TABLE_

    written := 0
    while written < out_buf_.size:
      result := write_block.call out_buf_[written..]
      written += result

  // We can output 3 bits of WS2812B protocol by sending nine high or low
  // signals.
  // We use the start bit as the first high, followed by 7 controllable
  // high/lows, and the stop bit as the final low.
  // Each bit is represented by high-low-low or high-high-low.
  // Luckily the start bit is high (after inverting), and the stop bit is low
  // (after inverting).
  // Note that the serial port is little endian bit order whereas the protocol
  // expects big endian bit order.
  static ENCODING_TABLE_3_BIT_ ::= #[
    // Because of inversion, 0 represents high and 1 represents high.
    0b10_110_11,   // 0b000
    0b00_110_11,   // 0b001
    0b10_100_11,   // 0b010
    0b00_100_11,   // 0b011
    0b10_110_10,   // 0b100
    0b00_110_10,   // 0b101
    0b10_100_10,   // 0b110
    0b00_100_10,   // 0b111
  ]

  // Blit requires a 256-entry table although only the first 8 entries will be
  // used.
  static TABLE_ ::= ByteArray 256: it < 8 ? ENCODING_TABLE_3_BIT_[it] : 0

class UartPixelStrip_ extends UartEncodingPixelStrip_:
  port_ /uart.Port? := ?
  pin_ /gpio.Pin? := null  // Only set if the pin needs closing.

  constructor pixels/int --pin/any --invert_pin/bool=true --bytes_per_pixel/int:
    // To use a UART port for WS2812B protocol we set the speed to 2.5 Mbaud,
    // which enables us to control the TX line with a 400ns granularity.
    // Serial lines are normally high when idle, but the protocol requires
    // low when idle, so we invert the signal by default.  This also means the start
    // bit, normally low, is now high.
    tx /gpio.Pin := ?
    if pin is int:
      tx = gpio.Pin.out pin
      pin_ = tx
    else:
      tx = pin

    port_ = uart.Port
      --tx=tx
      --rx=null
      --baud_rate=2_500_000  // For a 400ns granularity.
      --data_bits=7
      --invert_tx=invert_pin

    super pixels --bytes_per_pixel=bytes_per_pixel

  close->none:
    if not port_: return
    port_.close
    port_ = null
    if pin_:
      pin_.close
      pin_ = null

  is_closed -> bool:
    return not port_

  output_interleaved interleaved_data/ByteArray -> none:
    output_interleaved_ interleaved_data: port_.write it

/**
Deprecated. Use $PixelStrip.uart instead.
*/
class UartPixelStrip extends UartPixelStrip_:
  /**
  Deprecated. Use $PixelStrip.uart instead.
  */
  constructor pixels/int --pin/any --invert_pin/bool=true --bytes_per_pixel/int=3:
    super pixels --pin=pin --invert_pin=invert_pin --bytes_per_pixel=bytes_per_pixel
