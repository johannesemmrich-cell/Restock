#!/usr/bin/env python3
"""Misst die Roundtrip-Zeit zum Echo-Server (Näherung: Einweg ≈ RTT / 2).

Auf dem Mac, in einem zweiten Terminal zuerst den Tunnel öffnen:
  ssh -N -L 8765:127.0.0.1:8765 <benutzer>@<server>
Dann:  pip install websockets && python3 ws_client.py [Anzahl, Standard 50]
"""
import asyncio
import statistics
import sys
import time
import websockets


async def main(n):
    rtts = []
    async with websockets.connect("ws://127.0.0.1:8765") as ws:
        for _ in range(n):
            t0 = time.perf_counter()
            await ws.send("ping")
            await ws.recv()
            rtts.append((time.perf_counter() - t0) * 1000)
            await asyncio.sleep(1)
    rtts.sort()
    print(f"n={n}  RTT ms: min {rtts[0]:.0f}  Median {statistics.median(rtts):.0f}  "
          f"p95 {rtts[int(n * 0.95) - 1]:.0f}  max {rtts[-1]:.0f}")
    print(f"Einweg ≈ {statistics.median(rtts) / 2:.0f} ms (Median)")


asyncio.run(main(int(sys.argv[1]) if len(sys.argv) > 1 else 50))
