SELECT
  symbol,
  timeframe,
  TIMESTAMP(kline_start_time, "Europe/Warsaw") AS kline_start_ts,
  kline_start_time,
  open_price,
  high_price,
  low_price,
  close_price,
  number_of_trades,
  is_kline_closed
FROM `mineral-brand-231612.curated.market_klines`;
