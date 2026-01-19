-- =========================================================
-- Script de Optimización de Tablas
-- Aplicar particionado y clustering a tablas existentes
-- =========================================================

-- NOTA: BigQuery no permite cambiar particionado/clustering en tablas existentes
-- Este script muestra cómo recrear las tablas con optimización
-- Ejecutar solo si es necesario recrear las tablas

-- =========================================================
-- STAGE: stg_events_flat
-- =========================================================
-- Ya tiene particionado por event_date_partition (DATE)
-- Clustering: event_name, user_pseudo_id, session_id

-- Verificar particionado actual
SELECT
  table_name,
  partition_id,
  total_rows,
  total_logical_bytes
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'stg_events_flat'
ORDER BY partition_id DESC
LIMIT 10;

-- =========================================================
-- STAGE: stg_sessions
-- =========================================================
-- Particionado por session_date (DATE)
-- Clustering: session_id, source, medium, has_conversion

-- Verificar particionado
SELECT
  table_name,
  partition_id,
  total_rows,
  total_logical_bytes
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'stg_sessions'
ORDER BY partition_id DESC
LIMIT 10;

-- =========================================================
-- OLAP: fact_sessions
-- =========================================================
-- Particionado por session_date (DATE)
-- Clustering: date_key, channel_key, has_conversion

-- Verificar uso de clustering
SELECT
  table_name,
  clustering_ordinal_position,
  column_name
FROM `PROJECT_ID.olap.INFORMATION_SCHEMA.TABLE_OPTIONS`
WHERE table_name = 'fact_sessions'
  AND option_name = 'clustering_columns';

-- =========================================================
-- OLAP: fact_events
-- =========================================================
-- Particionado por event_date (DATE)
-- Clustering: session_id, event_name, event_timestamp

-- =========================================================
-- OLAP: fact_conversions
-- =========================================================
-- Particionado por conversion_date (DATE)
-- Clustering: date_key, channel_key, conversion_type

-- =========================================================
-- Recomendaciones de Optimización
-- =========================================================

-- 1. Verificar tamaño de particiones (ideal: 1-2 GB por partición)
SELECT
  table_name,
  partition_id,
  ROUND(total_logical_bytes / POW(10, 9), 2) AS size_gb,
  total_rows,
  CASE
    WHEN total_logical_bytes / POW(10, 9) < 0.5 THEN 'Muy pequeña - considerar consolidar'
    WHEN total_logical_bytes / POW(10, 9) > 2 THEN 'Muy grande - considerar subparticionar'
    ELSE 'Tamaño óptimo'
  END AS recommendation
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('stg_events_flat', 'stg_sessions')
ORDER BY table_name, partition_id DESC
LIMIT 20;

-- 2. Verificar efectividad del clustering
-- Queries que se benefician del clustering deben escanear menos datos
SELECT
  job_id,
  creation_time,
  total_bytes_processed,
  total_bytes_billed,
  query
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND statement_type = 'SELECT'
  AND total_bytes_processed > POW(10, 9)  -- > 1 GB
ORDER BY total_bytes_processed DESC
LIMIT 10;

-- 3. Estadísticas de uso de particiones
SELECT
  table_name,
  COUNT(DISTINCT partition_id) AS num_partitions,
  MIN(partition_id) AS oldest_partition,
  MAX(partition_id) AS newest_partition,
  SUM(total_rows) AS total_rows,
  ROUND(SUM(total_logical_bytes) / POW(10, 12), 2) AS total_size_tb
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('stg_events_flat', 'stg_sessions')
GROUP BY table_name;

-- =========================================================
-- Mantenimiento: Eliminar particiones antiguas (opcional)
-- =========================================================

-- Eliminar datos de más de 2 años (ajustar según política de retención)
-- DELETE FROM `PROJECT_ID.stage_ga4.stg_events_flat`
-- WHERE event_date_partition < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

-- DELETE FROM `PROJECT_ID.stage_ga4.stg_sessions`
-- WHERE session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

-- DELETE FROM `PROJECT_ID.olap.fact_sessions`
-- WHERE session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);
