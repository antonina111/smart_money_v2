import asyncio
import json
import os
import websockets
from datetime import datetime

from google.cloud import pubsub_v1

SYMBOL = "btcusdc"
INTERVAL = "1h"
STREAM_URL = f"wss://stream.binance.com:9443/ws/{SYMBOL}@kline_{INTERVAL}"
LOG_FILE = "/var/log/kline/kline.log"

PROJECT_ID = os.getenv("PROJECT_ID")
TOPIC_ID = os.getenv("TOPIC_ID")

publisher = pubsub_v1.PublisherClient()

if not PROJECT_ID:
    raise RuntimeError("PROJECT_ID environment variable is not set")
if not TOPIC_ID:
    raise RuntimeError("TOPIC_ID environment variable is not set")

TOPIC_PATH = publisher.topic_path(PROJECT_ID, TOPIC_ID)

async def main():
    with open(LOG_FILE, "a", buffering=1) as log:
        def log_print(*args):
            msg = " ".join(str(a) for a in args)
            print(msg)
            log.write(f"{datetime.now()} {msg}\n")

        log_print(f"Connecting to Binance WebSocket for {SYMBOL.upper()} {INTERVAL} klines...")
        async with websockets.connect(STREAM_URL) as websocket:
            log_print("Connected.")
            while True:
                try:
                    message = await websocket.recv()
                    data = json.loads(message)
                    kline = data.get("k")
                    if not kline:
                        continue
                    if kline.get("x"):  # closed candle
                        serialized = json.dumps(kline)
                        log_print("Kline closed:", serialized)

                        # Publish to Pub/Sub
                        future = publisher.publish(
                            TOPIC_PATH,
                            serialized.encode("utf-8"),
                            symbol=SYMBOL,
                            interval=INTERVAL
                        )
                        # optional: wait for ack to see errors
                        future.result(timeout=10)
                        log_print("Published to Pub/Sub:", TOPIC_PATH)
                except Exception as e:
                    log_print("Error:", e)
                    await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
