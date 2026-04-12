CREATE OR REPLACE TABLE `mineral-brand-231612.analytics.fact_smart_money_signals` AS
WITH base AS (
  SELECT
    CONCAT(symbol, '_', timeframe, '_', CAST(kline_start_time AS STRING)) AS kline_id,
    message_id,
    publish_time,
    kline_start_time,
    kline_close_time,
    symbol,
    timeframe,
    open_price,
    close_price,
    high_price,
    low_price,
    quote_asset_volume,
    base_asset_volume,
    number_of_trades,
    taker_buy_base_asset_volume,
    taker_buy_quote_asset_volume,

    CASE
      WHEN close_price > open_price THEN 'bullish'
      WHEN close_price < open_price THEN 'bearish'
      ELSE 'neutral'
    END AS candle_direction,

    SAFE_DIVIDE(close_price - open_price, open_price) * 100 AS price_change_pct,
    SAFE_DIVIDE(high_price - low_price, open_price) * 100 AS price_range_pct,
    SAFE_DIVIDE(taker_buy_quote_asset_volume, quote_asset_volume) AS buy_pressure_ratio,

    AVG(quote_asset_volume) OVER (
      PARTITION BY symbol, timeframe
      ORDER BY kline_start_time
      ROWS BETWEEN 24 PRECEDING AND 1 PRECEDING
    ) AS avg_quote_asset_volume_24,

    AVG(number_of_trades) OVER (
      PARTITION BY symbol, timeframe
      ORDER BY kline_start_time
      ROWS BETWEEN 24 PRECEDING AND 1 PRECEDING
    ) AS avg_number_of_trades_24

  FROM `mineral-brand-231612.curated.market_klines`
),

scored AS (
  SELECT
    *,
    SAFE_DIVIDE(quote_asset_volume, avg_quote_asset_volume_24) AS volume_anomaly_ratio,
    SAFE_DIVIDE(number_of_trades, avg_number_of_trades_24) AS trades_anomaly_ratio,

    CASE
      WHEN SAFE_DIVIDE(quote_asset_volume, avg_quote_asset_volume_24) > 1.5 THEN TRUE
      ELSE FALSE
    END AS is_volume_anomaly,

    CASE
      WHEN SAFE_DIVIDE(number_of_trades, avg_number_of_trades_24) > 1.5 THEN TRUE
      ELSE FALSE
    END AS is_trade_anomaly,

    CASE
      WHEN SAFE_DIVIDE(taker_buy_quote_asset_volume, quote_asset_volume) > 0.6 THEN TRUE
      ELSE FALSE
    END AS is_buy_pressure_high
  FROM base
)

SELECT
  *,
  CASE
    WHEN candle_direction = 'bullish'
         AND volume_anomaly_ratio > 1.5
         AND buy_pressure_ratio > 0.6
      THEN 'smart_money_bullish'

    WHEN candle_direction = 'bearish'
         AND volume_anomaly_ratio > 1.5
         AND buy_pressure_ratio < 0.4
      THEN 'smart_money_bearish'

    ELSE 'neutral'
  END AS smart_money_signal,

  LEAST(
    100,
    COALESCE(volume_anomaly_ratio * 25, 0) +
    COALESCE(trades_anomaly_ratio * 20, 0) +
    COALESCE(buy_pressure_ratio * 30, 0)
  ) AS smart_money_score
FROM scored;