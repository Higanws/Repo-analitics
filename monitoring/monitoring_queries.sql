-- =========================================================
-- Queries Útiles para Monitoreo Operacional
-- =========================================================

-- =========================================================
-- 1. Resumen de Ejecuciones Recientes
-- =========================================================
SELECT
  dag_id,
  task_id,
  status,
  COUNT(*) AS execution_count,
  AVG(duration_seconds) AS avg_duration_seconds,
  SUM(rows_processed) AS total_rows,
  ROUND(SUM(bytes_processed) / POW(10, 9), 2) AS total_gb_processed
FROM `PROJECT_ID.monitoring.etl_run_log`
WHERE run_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY dag_id, task_id, status
ORDER BY dag_id, task_id;

-- =========================================================
-- 2. Tendencias de Volumen de Datos
-- =========================================================
SELECT
  event_date_partition AS date,
  COUNT(*) AS events_count,
  COUNT(DISTINCT session_id) AS unique_sessions,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  ROUND(COUNT(*) / COUNT(DISTINCT session_id), 2) AS avg_events_per_session
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY event_date_partition
ORDER BY event_date_partition DESC;

-- =========================================================
-- 3. Performance de Queries BigQuery
-- =========================================================
SELECT
  DATE(creation_time) AS query_date,
  COUNT(*) AS total_queries,
  COUNTIF(total_bytes_billed > POW(10, 9)) AS large_queries,
  ROUND(AVG(total_bytes_billed) / POW(10, 9), 2) AS avg_gb_billed,
  ROUND(SUM(total_bytes_billed) / POW(10, 12), 2) AS total_tb_billed,
  ROUND(AVG(total_slot_ms) / 1000, 2) AS avg_slot_seconds
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND statement_type = 'SELECT'
GROUP BY query_date
ORDER BY query_date DESC;

-- =========================================================
-- 4. Uso de Particiones
-- =========================================================
SELECT
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(10, 9), 2) AS size_gb,
  ROUND(total_logical_bytes / POW(10, 12), 2) AS size_tb
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('stg_events_flat', 'stg_sessions')
  AND partition_id >= FORMAT_DATE('%Y-%m-%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
ORDER BY table_name, partition_id DESC;

-- =========================================================
-- 5. Efectividad del Clustering
-- =========================================================
-- Verificar queries que escanean menos datos gracias al clustering
SELECT
  job_id,
  creation_time,
  total_bytes_processed,
  total_bytes_billed,
  SUBSTR(query, 0, 100) AS query_preview
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND statement_type = 'SELECT'
  AND total_bytes_processed > 0
  AND total_bytes_processed < total_bytes_billed * 0.5  -- Beneficio del clustering
ORDER BY total_bytes_processed DESC
LIMIT 10;

-- =========================================================
-- 6. Métricas de Conversión por Canal
-- =========================================================
SELECT
  dchan.channel_group,
  dchan.channel_type,
  COUNT(DISTINCT fs.session_id) AS sessions,
  SUM(fs.has_conversion) AS conversions,
  ROUND(SUM(fs.has_conversion) / COUNT(DISTINCT fs.session_id) * 100, 2) AS conversion_rate,
  SUM(fs.total_conversion_value) AS total_conversion_value
FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_channel` dchan ON fs.channel_key = dchan.channel_key
WHERE fs.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY dchan.channel_group, dchan.channel_type
ORDER BY sessions DESC;

-- =========================================================
-- 7. Health Check del Pipeline
-- =========================================================
WITH latest_runs AS (
  SELECT
    dag_id,
    MAX(run_timestamp) AS last_run,
    MAX(run_date) AS last_run_date
  FROM `PROJECT_ID.monitoring.etl_run_log`
  GROUP BY dag_id
),
status_check AS (
  SELECT
    lr.dag_id,
    lr.last_run,
    lr.last_run_date,
    CASE
      WHEN lr.last_run_date < DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN 'STALE'
      WHEN EXISTS (
        SELECT 1 FROM `PROJECT_ID.monitoring.etl_run_log` r
        WHERE r.dag_id = lr.dag_id
          AND r.run_date = lr.last_run_date
          AND r.status = 'failed'
      ) THEN 'FAILED'
      ELSE 'HEALTHY'
    END AS health_status
  FROM latest_runs lr
)
SELECT * FROM status_check;
