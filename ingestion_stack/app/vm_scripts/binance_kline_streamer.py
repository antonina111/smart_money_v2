import asyncio
import json
import os
from datetime import datetime, timezone

import websockets
from google.cloud import pubsub_v1

SYMBOL = "btcusdc"
INTERVAL = "1h"
STREAM_URL = f"wss://stream.binance.com:9443/ws/{SYMBOL}@kline_{INTERVAL}"
LOG_FILE = "/var/log/kline/kline.log"

PROJECT_ID = os.getenv("PROJECT_ID")
TOPIC_ID = os.getenv("TOPIC_ID")

if not PROJECT_ID:
    raise RuntimeError("PROJECT_ID environment variable is not set")
if not TOPIC_ID:
    raise RuntimeError("TOPIC_ID environment variable is not set")

publisher = pubsub_v1.PublisherClient()
TOPIC_PATH = publisher.topic_path(PROJECT_ID, TOPIC_ID)


def log_print(*args):
    msg = " ".join(str(a) for a in args)
    ts = datetime.now(timezone.utc).isoformat()
    line = f"{ts} {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", buffering=1) as log:
            log.write(line + "\n")
    except Exception:
        pass


async def stream_forever():
    """Reconnect loop: keep connecting to Binance and streaming klines."""
    while True:
        try:
            log_print(f"Connecting to Binance WebSocket for {SYMBOL.upper()} {INTERVAL} klines...")
            async with websockets.connect(
                STREAM_URL,
                ping_interval=20,
                ping_timeout=20,
                close_timeout=10,
            ) as websocket:
                log_print("Connected.")

                async for message in websocket:
                    try:
                        data = json.loads(message)
                        kline = data.get("k")
                        if not kline:
                            continue

                        if kline.get("x"):  # closed candle
                            serialized = json.dumps(kline)
                            log_print("Kline closed:", serialized)

                            future = publisher.publish(
                                TOPIC_PATH,
                                serialized.encode("utf-8"),
                                symbol=SYMBOL,
                                ingestion_type="websocket",
                                source_type="cryptocurrency_exchange",
                                source_name="binance",
                                interval=INTERVAL,
                            )
                            # wait for ack to catch publish errors
                            future.result(timeout=10)
                            log_print("Published to Pub/Sub:", TOPIC_PATH)
                    except Exception as e:
                        log_print("Error while processing message:", repr(e))
        except Exception as e:
            log_print("Connection error, will reconnect in 5s:", repr(e))
            await asyncio.sleep(5)


def main():
    log_print("Starting kline streamer...")
    try:
        asyncio.run(stream_forever())
    except KeyboardInterrupt:
        log_print("Shutting down due to KeyboardInterrupt.")


if __name__ == "__main__":
    main()
