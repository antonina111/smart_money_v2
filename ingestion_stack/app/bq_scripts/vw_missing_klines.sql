WITH
-- Define start and end datetimes
  params AS (
    SELECT
      TIMESTAMP("2025-01-01") AS start_datetime,
      CURRENT_TIMESTAMP()      AS end_datetime
  ),
  calendar AS (
    SELECT DATETIME(ts) AS dt
    FROM params,
    UNNEST(
      GENERATE_TIMESTAMP_ARRAY(
        start_datetime,
        end_datetime,
        INTERVAL 1 HOUR
      )
    ) ts
  ),
  joined AS (
    SELECT
      c.dt,
      k.kline_start_time IS NOT NULL AS has_data
    FROM calendar c
    LEFT JOIN `mineral-brand-231612.curated.market_klines` AS k
      ON k.kline_start_time = c.dt
  ),
  gaps AS (
    SELECT
      dt,
      has_data,
      LAG(has_data)  OVER (ORDER BY dt) AS prev_has_data,
      LEAD(has_data) OVER (ORDER BY dt) AS next_has_data
    FROM joined
  ),
  -- Identify gap starts assuming gaps are continuous blocks of missing hours
  gap_starts AS (
    SELECT
      dt AS gap_start,
      ROW_NUMBER() OVER (ORDER BY dt) AS gap_id
    FROM gaps
    WHERE has_data = FALSE
      AND (prev_has_data IS TRUE OR prev_has_data IS NULL)
  ),
    -- Identify gap ends
  gap_ends AS (
    SELECT
      dt AS gap_end,
      ROW_NUMBER() OVER (ORDER BY dt) AS gap_id
    FROM gaps
    WHERE has_data = FALSE
      AND (next_has_data IS TRUE OR next_has_data IS NULL)
  )
-- Combine gap starts and ends by gap_id
SELECT
  s.gap_start,
  e.gap_end
FROM gap_starts s
JOIN gap_ends e USING (gap_id)
ORDER BY s.gap_start;
