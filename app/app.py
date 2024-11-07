import asyncio
import json
import websockets
from snowplow_analytics_sdk import event_transformer

CONNECTIONS = set()

async def echo(websocket):
    if websocket not in CONNECTIONS:
        print('adding new connection...')
        CONNECTIONS.add(websocket)

    async for message in websocket:
        try:
            transformed = json.dumps(event_transformer.transform(message.decode('utf-8')))
        except Exception as e:
            print('Failed to transform event:', e)
            transformed = json.dumps({})
            pass

        websockets.broadcast(CONNECTIONS, transformed)

async def main():
    async with websockets.serve(echo, "0.0.0.0", 8765):
        await asyncio.Future()  # run forever

asyncio.run(main())