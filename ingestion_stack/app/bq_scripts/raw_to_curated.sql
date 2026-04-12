/*
 * Description: Script used for cleaning raw data and uploading into curated layer

 * Inputs:  - `mineral-brand-231612.raw.market_klines`

 * Outputs: - `mineral-brand-231612.curated.market_klines`

*/

SELECT
  message_id,
  DATETIME(publish_time, "Europe/Warsaw") as publish_time,
  JSON_VALUE(attributes, '$.ingestion_type') AS ingestion_type,
  JSON_VALUE(attributes, '$.source_type') AS source_type,
  JSON_VALUE(attributes, '$.source_name') AS source_name,
  DATETIME(TIMESTAMP_MILLIS(CAST(JSON_VALUE(DATA, '$.t') AS INT64)), "Europe/Warsaw") AS kline_start_time,
  DATETIME(TIMESTAMP_MILLIS(CAST(JSON_VALUE(DATA, '$.T') AS INT64)), "Europe/Warsaw") AS kline_close_time,
  JSON_VALUE(DATA, '$.s') AS symbol,
  JSON_VALUE(DATA, '$.i') AS timeframe,
  CAST(JSON_VALUE(DATA, '$.f') AS INT64) AS first_trade_id,
  CAST(JSON_VALUE(DATA, '$.L') AS INT64) AS last_trade_id,
  CAST(JSON_VALUE(DATA, '$.o') AS FLOAT64) AS open_price,
  CAST(JSON_VALUE(DATA, '$.c') AS FLOAT64) AS close_price,
  CAST(JSON_VALUE(DATA, '$.h') AS FLOAT64) AS high_price,
  CAST(JSON_VALUE(DATA, '$.l') AS FLOAT64) AS low_price,
  CAST(JSON_VALUE(DATA, '$.v') AS FLOAT64) AS base_asset_volume,
  CAST(JSON_VALUE(DATA, '$.n') AS INT64) AS number_of_trades,
  CAST(JSON_VALUE(DATA, '$.x') AS BOOL) AS is_kline_closed,
  CAST(JSON_VALUE(DATA, '$.q') AS FLOAT64) AS quote_asset_volume,
  CAST(JSON_VALUE(DATA, '$.V') AS FLOAT64) AS taker_buy_base_asset_volume,
  CAST(JSON_VALUE(DATA, '$.Q') AS FLOAT64) AS taker_buy_quote_asset_volume,
  CAST(JSON_VALUE(DATA, '$.B') AS INT64) AS ignore_value,
FROM
  `mineral-brand-231612.raw.market_klines`
WHERE JSON_VALUE(DATA, '$.i') IN ("1h", "2h")
AND JSON_VALUE(attributes, '$.ingestion_type') = "websocket"

UNION ALL

SELECT
  message_id,
  DATETIME(publish_time, "Europe/Warsaw") AS publish_time,
  JSON_VALUE(attributes, '$.ingestion_type') AS ingestion_type,
  JSON_VALUE(attributes, '$.source_type') AS source_type,
  JSON_VALUE(attributes, '$.source_name') AS source_name,
  DATETIME(TIMESTAMP_MILLIS(CAST(JSON_VALUE_ARRAY(DATA)[0] AS INT64)), "Europe/Warsaw") AS kline_start_time,
  DATETIME(TIMESTAMP_MILLIS(CAST(JSON_VALUE_ARRAY(DATA)[6] AS INT64)), "Europe/Warsaw") AS kline_close_time,
  JSON_VALUE(attributes, '$.symbol') AS symbol,
  JSON_VALUE(attributes, '$.interval') AS timeframe,
  NULL AS first_trade_id,
  NULL AS last_trade_id,
  CAST(JSON_VALUE_ARRAY(DATA)[1] AS FLOAT64) AS opne_price,
  CAST(JSON_VALUE_ARRAY(DATA)[4] AS FLOAT64) AS close_price,
  CAST(JSON_VALUE_ARRAY(DATA)[2] AS FLOAT64) AS high_price,
  CAST(JSON_VALUE_ARRAY(DATA)[3] AS FLOAT64) AS low_price,
  NULL AS base_asset_volume,
  CAST(JSON_VALUE_ARRAY(DATA)[8] AS INT64) AS number_of_trades,
  TRUE AS is_kline_closed,
  CAST(JSON_VALUE_ARRAY(DATA)[7] AS FLOAT64) AS quote_asset_volume,
  CAST(JSON_VALUE_ARRAY(DATA)[9] AS FLOAT64) AS taker_buy_base_asset_volume,
  CAST(JSON_VALUE_ARRAY(DATA)[10] AS FLOAT64) AS taker_buy_quote_asset_volume,
  CAST(JSON_VALUE_ARRAY(DATA)[11] AS FLOAT64) ignore_value
FROM
  `mineral-brand-231612.raw.market_klines`
WHERE
  JSON_VALUE(attributes, '$.ingestion_type') = "backfill"
