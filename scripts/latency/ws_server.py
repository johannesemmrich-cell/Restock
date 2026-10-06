#!/usr/bin/env python3
"""Echo-Server für den Latenztest (Näherung). Bindet nur an 127.0.0.1, Erreichbarkeit per SSH-Tunnel.

Auf dem Server:  pip install websockets && python3 ws_server.py
"""
import asyncio
import websockets


async def echo(ws):
    async for msg in ws:
        await ws.send(msg)


async def main():
    async with websockets.serve(echo, "127.0.0.1", 8765):
        await asyncio.Future()


asyncio.run(main())
