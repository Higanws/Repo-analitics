-- =========================================================
-- Tabla de Auditoría ETL
-- Registra todas las ejecuciones del pipeline
-- =========================================================

CREATE TABLE IF NOT EXISTS `PROJECT_ID.monitoring.etl_run_log`
(
  run_id STRING,
  run_date DATE,
  dag_id STRING,
  task_id STRING,
  status STRING,  -- 'success', 'failed', 'running'
  rows_processed INT64,
  bytes_processed INT64,
  duration_seconds INT64,
  error_message STRING,
  run_timestamp TIMESTAMP
)
PARTITION BY run_date
CLUSTER BY dag_id, status, run_timestamp;

-- Comentarios
ALTER TABLE `PROJECT_ID.monitoring.etl_run_log`
SET OPTIONS(
  description="Tabla de auditoría para registrar ejecuciones del pipeline ETL. Particionada por run_date, clusterizada por dag_id, status y run_timestamp."
);

-- Vista para últimas ejecuciones
CREATE OR REPLACE VIEW `PROJECT_ID.monitoring.vw_recent_runs` AS
SELECT
  run_id,
  run_date,
  dag_id,
  task_id,
  status,
  rows_processed,
  ROUND(bytes_processed / POW(10, 9), 2) AS bytes_processed_gb,
  duration_seconds,
  error_message,
  run_timestamp
FROM `PROJECT_ID.monitoring.etl_run_log`
WHERE run_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY run_timestamp DESC;

-- Vista para resumen diario
CREATE OR REPLACE VIEW `PROJECT_ID.monitoring.vw_daily_summary` AS
SELECT
  run_date,
  dag_id,
  COUNT(*) AS total_runs,
  COUNTIF(status = 'success') AS successful_runs,
  COUNTIF(status = 'failed') AS failed_runs,
  SUM(rows_processed) AS total_rows_processed,
  ROUND(SUM(bytes_processed) / POW(10, 12), 2) AS total_bytes_processed_tb,
  AVG(duration_seconds) AS avg_duration_seconds
FROM `PROJECT_ID.monitoring.etl_run_log`
WHERE run_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY run_date, dag_id
ORDER BY run_date DESC;
