import json
import os
import time
import datetime as dt
import requests
from google.cloud import bigquery

BINANCE_BASE = "https://api.binance.com"
symbol = "btcusdc"
interval = "1h"

PROJECT_ID = os.getenv("PROJECT_ID")
DATASET = "raw"
TABLE = "market_klines"
LOG_FILE = "/var/log/kline/kline_backfill.log"

start = dt.datetime(2025, 11, 1, 0, 0, 0, tzinfo=dt.timezone.utc)
end   = dt.datetime(2025, 11, 2, 0, 0, 0, tzinfo=dt.timezone.utc)

bq_client = bigquery.Client(project=PROJECT_ID)
table_id = f"{PROJECT_ID}.{DATASET}.{TABLE}"


def fetch_klines(symbol, interval, start_ms, end_ms):
    url = f"{BINANCE_BASE}/api/v3/klines"
    symbol_api = symbol.upper()
    params = {
        "symbol": symbol_api,
        "interval": interval,
        "startTime": start_ms,
        "endTime": end_ms,
        "limit": 1000,
    }
    resp = requests.get(url, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json()


def insert_backfill_batch(symbol, interval, klines):

    rows = []

    for k in klines:
        attributes = {
            "interval": interval,
            "symbol": symbol,
            "ingestion_type": "backfill",
            "source_type": "cryptocurrency_exchange",
            "source_name": "binance"
        }

        row = {
            "data": json.dumps(k),
            "attributes": json.dumps(attributes),
            "message_id": f"backfill-{symbol}-{interval}-{k[0]}",
            "publish_time": dt.datetime.now(dt.timezone.utc).isoformat(),
            "subscription_name": "manual_backfill"
            }
        rows.append(row)

    errors = bq_client.insert_rows_json(table_id, rows)
    if errors:
        raise RuntimeError(errors)


def backfill_range(symbol, interval, start_ms, end_ms):
    current = start_ms
    inserted_total = 0

    while current < end_ms:
        klines = fetch_klines(symbol, interval, current, end_ms)
        if not klines:
            break

        insert_backfill_batch(symbol, interval, klines)
        inserted_total += len(klines)

        # get last closed kline time and move to next ms
        last_close_time_ms = klines[-1][6]
        current = last_close_time_ms + 1

        # to respect rate limits
        time.sleep(200 / 1000.0)

    return inserted_total

if __name__ == "__main__":
    with open(LOG_FILE, "a", buffering=1) as log:
        def log_print(*args):
            msg = " ".join(str(a) for a in args)
            print(msg)
            log.write(f"{dt.datetime.now()} {msg}\n")
        try:
            start_ms = int(start.timestamp() * 1000)
            end_ms   = int(end.timestamp() * 1000) - 1  # Binance endTime
            log_print(f"Starting backfill for {symbol} {interval} from {start} to {end}...")
            total = backfill_range(symbol, interval, start_ms, end_ms)
            print(f"Inserted total {total} klines for {symbol} {interval} from {start} to {end}")

        except Exception as e:
            log_print("Error:", e)
