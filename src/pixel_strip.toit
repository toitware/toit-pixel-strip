import gpio
import i2s
import uart
import bitmap show blit bytemap_zap OR

abstract class PixelStrip:
  pixels_/int := ?
  bytes_per_pixel_ := ?
  inter_ := ?

  inter_1_ := ?
  inter_2_ := ?
  inter_3_ := null

  /// The number of pixels in the strip.
  pixels->int: return pixels_

  constructor .pixels_/int --bytes_per_pixel=3:
    bytes_per_pixel_ = bytes_per_pixel
    inter_ = ByteArray pixels_ * bytes_per_pixel_
    inter_1_ = inter_[1..]
    inter_2_ = inter_[2..]
    if bytes_per_pixel > 3: inter_3_ = inter_[3..]

  /**
  Takes three or four byte arrays of pixel values (depending on the number of
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte arrays, so you can reuse them for the next
    frame.
  */
  output r/ByteArray g/ByteArray b/ByteArray w/ByteArray?=null -> none:
    // Interleave r, g, b, and w.
    blit g inter_   pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit r inter_1_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    blit b inter_2_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    if bytes_per_pixel_ > 3:
      blit w inter_3_ pixels_ --destination_pixel_stride=bytes_per_pixel_
    output_interleaved

  /**
  Takes one byte array of pixel values, interleaved in GRB order, or
    GRBW order for strips with 4 bytes per pixel.
    bytes per pixel passed to the constructor) and outputs them to the
    strip.  The byte arrays should have the same size as $pixels.
  Data is copied out of the byte array, so you can reuse it for the next
    frame.
  */
  abstract output_interleaved -> none

/**
A driver that sends data to attached WS2812B LED strips, sometimes
  called Neopixel.  The UART driver is used.
*/
class UartPixelStrip extends PixelStrip:
  out_buf_ := ?
  out_buf_1_ := ?
  out_buf_2_ := ?
  out_buf_3_ := ?
  out_buf_4_ := ?
  out_buf_5_ := ?
  out_buf_6_ := ?
  out_buf_7_ := ?
  port_/uart.Port := ?

  /**
  A driver that sends data to attached WS2812B LED strips, sometimes
    called Neopixel.  The UART driver is used.  Preferred pin is pin
    17, but others should work.
  Normally you need to invert the TX pin of a UART to use it for
    WS2812B LED strips.  Often you also need a level shifter to
    convert from 3.3V to 5V.  If your level shifter also inverts
    the pin you can disable the inverted pin support with $invert_pin.
  If your strip is RGB (24 bits per pixel), leave $bytes_per_pixel at
    3.  For RGB+WW (warm white) strips with 32 bits per pixel, specify
    $bytes_per_pixel as 4.
  */
  constructor pixels/int --pin/int=17 --invert_pin=true --bytes_per_pixel=3:
    if bytes_per_pixel == 3:
      out_buf_ = ByteArray pixels * 8
    else:
      out_buf_ = ByteArray (pixels * bytes_per_pixel * 8) / 3 + 2
    out_buf_1_ = out_buf_[1..]
    out_buf_2_ = out_buf_[2..]
    out_buf_3_ = out_buf_[3..]
    out_buf_4_ = out_buf_[4..]
    out_buf_5_ = out_buf_[5..]
    out_buf_6_ = out_buf_[6..]
    out_buf_7_ = out_buf_[7..]

    // To use a UART port for WS2812B protocol we set the speed to 2.5 Mbaud,
    // which enables us to control the TX line with a 400ns granularity.
    // Serial lines are normally high when idle, but the protocol requires
    // low when idle, so we invert the signal.  This also means the start
    // bit, normally low, is now high.
    tx := gpio.Pin.out pin
    port_ = uart.Port
      --tx=tx
      --rx=null
      --baud_rate=2_500_000  // For a 400ns granularity.
      --data_bits=7
      --invert_tx=invert_pin

    super pixels --bytes_per_pixel=bytes_per_pixel

  close->none:
    port_.close

  output_interleaved->none:
    steps := inter_.size / 3

    blit inter_   out_buf_   steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_0_
    blit inter_   out_buf_1_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_1_
    blit inter_   out_buf_2_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_2A_ --mask=0b00_111_11
    blit inter_1_ out_buf_2_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_2B_ --mask=0b11_000_00 --operation=OR
    blit inter_1_ out_buf_3_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_3_
    blit inter_1_ out_buf_4_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_4_
    blit inter_1_ out_buf_5_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_5A_ --mask=0b00_000_11
    blit inter_2_ out_buf_5_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_5B_ --mask=0b11_111_00 --operation=OR
    blit inter_2_ out_buf_6_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_6_
    blit inter_2_ out_buf_7_ steps --destination_pixel_stride=8 --source_pixel_stride=3 --lookup_table=TABLE_7_

    written := 0
    while written < out_buf_.size:
      result := port_.write out_buf_[written..]
      written += result
    port_.write #[] --wait

  static TABLE_0_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[it >> 5]
  static TABLE_1_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it >> 2) & 7]
  static TABLE_2A_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it << 1) & 7]
  static TABLE_2B_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[it >> 7]
  static TABLE_3_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it >> 4) & 7]
  static TABLE_4_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it >> 1) & 7]
  static TABLE_5A_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it << 2) & 7]
  static TABLE_5B_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[it >> 6]
  static TABLE_6_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[(it >> 3) & 7]
  static TABLE_7_ ::= ByteArray 256: ENCODING_TABLE_3_BIT_[it & 7]

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

/**
A driver that sends data to attached WS2812B LED strips, sometimes
  called Neopixel.  The I2S driver is used.
Deprecated.  The current esp-idf versions seem to have a bug
  where they replay old data instead of sending zeros on the
  I2S bus.  This makes this driver unreliable, so we are
  deprecating it until we can resolve the issue.  Please use
  UartPixelStrip instead.
*/
class I2SPixelStrip extends PixelStrip:
  out_buf_ := ?
  out_buf_0_ := ?
  out_buf_1_ := ?
  out_buf_2_ := ?
  out_buf_3_ := ?
  bus_/i2s.Bus := ?
  static BUFFER_SIZE_ ::= 128
  reset_ := ByteArray BUFFER_SIZE_

  /**
  If your strip is RGB (24 bits per pixel), leave $bytes_per_pixel at
    3.  For RGB+WW (warm white) strips with 32 bits per pixel, specify
    $bytes_per_pixel as 4.
  */
  constructor pixels/int --pin/int --bytes_per_pixel=3:
    out_buf_ = ByteArray
      round_up
        pixels * bytes_per_pixel * 4
        BUFFER_SIZE_
    print "out_buf_.size $out_buf_.size"
    out_buf_0_ = out_buf_[0..]
    out_buf_1_ = out_buf_[1..]
    out_buf_2_ = out_buf_[2..]
    out_buf_3_ = out_buf_[3..]

    tx := gpio.Pin.out pin
    bus_ = i2s.Bus --tx=tx --sample_rate=100_000 --bits_per_sample=16 --buffer_size=BUFFER_SIZE_

    super pixels --bytes_per_pixel=bytes_per_pixel

  close->none:

  output_interleaved->none:
    // TODO: We could save some memory using a 3-bit encoding of the signal
    // instead of the this 4-bit encoding.
    blit inter_ out_buf_3_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_0_
    blit inter_ out_buf_2_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_1_
    blit inter_ out_buf_1_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_2_
    blit inter_ out_buf_0_ pixels_ * bytes_per_pixel_ --destination_pixel_stride=4 --lookup_table=TABLE_3_

    bus_.write reset_
    written := bus_.write out_buf_
    if written != out_buf_.size: print "Tried to write $out_buf_.size, wrote $written"

  static TABLE_0_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[it >> 6]
  static TABLE_1_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[(it >> 4) & 3]
  static TABLE_2_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[(it >> 2) & 3]
  static TABLE_3_ ::= ByteArray 256: ENCODING_TABLE_2_BIT_[it & 3]

  // We can output 2 bits of WS2812B protocol by using each nibble on the I2S
  // bus to shape a pulse for the WS2812B.

  static ENCODING_TABLE_2_BIT_ ::= #[
    0b1000_1000,   // 0b00
    0b1000_1110,   // 0b01
    0b1110_1000,   // 0b10
    0b1110_1110,   // 0b11
    ]
