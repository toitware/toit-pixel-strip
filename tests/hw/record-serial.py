#!/usr/bin/env python3
# Copyright (C) 2026 Toit contributors.
# Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
"""Record a board console, reconnecting across resets. Requires pyserial."""
import argparse
import sys
import time

import serial


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True)
    parser.add_argument("--seconds", type=float, default=600)
    parser.add_argument("--until", help="Exit successfully when this text appears")
    args = parser.parse_args()
    deadline = time.monotonic() + args.seconds
    stream = None
    pending = ""
    try:
        while time.monotonic() < deadline:
            try:
                if stream is None:
                    stream = serial.Serial(args.port, 115200, timeout=0.2, exclusive=True)
                data = stream.read(4096)
                if not data:
                    continue
                text = data.replace(b"\x00", b"").decode(errors="replace")
                sys.stdout.write(text)
                sys.stdout.flush()
                if args.until:
                    pending += text
                    if args.until in pending:
                        return 0
                    pending = pending[-len(args.until):]
            except (serial.SerialException, OSError):
                if stream is not None:
                    stream.close()
                    stream = None
                time.sleep(0.1)
        return 1 if args.until else 0
    finally:
        if stream is not None:
            stream.close()


if __name__ == "__main__":
    raise SystemExit(main())
