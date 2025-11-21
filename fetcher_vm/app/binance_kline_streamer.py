import asyncio
import json
import websockets
from datetime import datetime

SYMBOL = "btcusdc"
INTERVAL = "1m"
STREAM_URL = f"wss://stream.binance.com:9443/ws/{SYMBOL}@kline_{INTERVAL}"
LOG_FILE = "/var/log/kline/kline.log"

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
                        log_print("Kline closed:", json.dumps(kline))
                except Exception as e:
                    log_print("Error:", e)
                    await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
