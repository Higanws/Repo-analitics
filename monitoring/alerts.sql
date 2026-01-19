-- =========================================================
-- Queries para Alertas y Monitoreo
-- Usar en Cloud Monitoring o ejecutar periódicamente
-- =========================================================

-- =========================================================
-- Alerta: Falta de datos diarios
-- =========================================================
SELECT
  'missing_daily_data' AS alert_type,
  DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS check_date,
  CASE
    WHEN COUNT(*) = 0 THEN 'FAIL'
    ELSE 'PASS'
  END AS status,
  COUNT(*) AS events_count
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- =========================================================
-- Alerta: Caída de volumen > 20%
-- =========================================================
WITH daily_volumes AS (
  SELECT
    event_date_partition AS date,
    COUNT(*) AS events_count
  FROM `PROJECT_ID.stage_ga4.stg_events_flat`
  WHERE event_date_partition >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY event_date_partition
),
volume_change AS (
  SELECT
    CURRENT.date,
    CURRENT.events_count,
    PREVIOUS.events_count AS previous_count,
    (CURRENT.events_count - PREVIOUS.events_count) / PREVIOUS.events_count AS pct_change
  FROM daily_volumes CURRENT
  LEFT JOIN daily_volumes PREVIOUS
    ON CURRENT.date = DATE_ADD(PREVIOUS.date, INTERVAL 1 DAY)
  WHERE CURRENT.date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
)
SELECT
  'volume_drop' AS alert_type,
  date AS check_date,
  CASE
    WHEN pct_change < -0.20 THEN 'FAIL'
    ELSE 'PASS'
  END AS status,
  events_count,
  previous_count,
  ROUND(pct_change * 100, 2) AS pct_change
FROM volume_change;

-- =========================================================
-- Alerta: Errores en Data Quality
-- =========================================================
SELECT
  'data_quality_failure' AS alert_type,
  check_date,
  COUNTIF(status = 'FAIL') AS failed_assertions,
  COUNT(*) AS total_assertions,
  CASE
    WHEN COUNTIF(status = 'FAIL') > 0 THEN 'FAIL'
    ELSE 'PASS'
  END AS status
FROM `PROJECT_ID.monitoring.data_quality_log`
WHERE check_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
GROUP BY check_date;

-- =========================================================
-- Alerta: DAG fallido
-- =========================================================
SELECT
  'dag_failure' AS alert_type,
  run_date,
  dag_id,
  COUNTIF(status = 'failed') AS failed_tasks,
  STRING_AGG(DISTINCT error_message, '; ') AS error_messages
FROM `PROJECT_ID.monitoring.etl_run_log`
WHERE run_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND status = 'failed'
GROUP BY run_date, dag_id;

-- =========================================================
-- Alerta: Alto costo de queries
-- =========================================================
SELECT
  'high_query_cost' AS alert_type,
  DATE(creation_time) AS query_date,
  COUNT(*) AS high_cost_queries,
  ROUND(SUM(total_bytes_billed) / POW(10, 12), 2) AS total_tb_billed
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND total_bytes_billed > POW(10, 12)  -- > 1 TB
GROUP BY query_date
HAVING total_tb_billed > 5;  -- Alerta si > 5 TB en un día

-- =========================================================
-- Alerta: Particiones muy grandes
-- =========================================================
SELECT
  'large_partition' AS alert_type,
  table_name,
  partition_id,
  ROUND(total_logical_bytes / POW(10, 9), 2) AS size_gb,
  total_rows,
  CASE
    WHEN total_logical_bytes / POW(10, 9) > 2 THEN 'WARNING'
    ELSE 'OK'
  END AS status
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('stg_events_flat', 'stg_sessions')
  AND partition_id = FORMAT_DATE('%Y-%m-%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  AND total_logical_bytes / POW(10, 9) > 2;
