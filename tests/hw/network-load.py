#!/usr/bin/env python3
# Copyright (C) 2026 Toit contributors.
# Use of this source code is governed by the Zero-Clause BSD license in tests/TESTS_LICENSE.
"""Exchange 1 KiB UDP packets with the pixel peer during its loaded cases."""
import argparse
import socket
import signal
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("host")
parser.add_argument("--seconds", type=float, default=600)
args = parser.parse_args()
end = time.monotonic() + args.seconds
sent = received = 0
payload = bytes(range(256)) * 4
running = True


def stop(signum, frame):
    global running
    running = False


signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as connection:
    connection.settimeout(0.05)
    while running and time.monotonic() < end:
        connection.sendto(payload, (args.host, 8989))
        sent += 1
        try:
            data, address = connection.recvfrom(2048)
            if data != payload or address[1] != 8989:
                raise RuntimeError("Unexpected UDP reply")
            received += 1
        except (socket.timeout, ConnectionRefusedError):
            pass
        time.sleep(0.02)
print(f"network-load: sent={sent}, echoed={received}")
if received == 0:
    raise SystemExit("No packets were echoed; network load was not exercised")
