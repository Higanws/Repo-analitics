-- =========================================================
-- Data Quality Assertions - OLAP
-- Validaciones sobre el modelo estrella OLAP
-- =========================================================

-- 1. Volumen de fact_sessions (debe ser > 0)
SELECT 
  'olap_fact_sessions_volume' AS assertion_name,
  COUNT(*) AS sessions_count,
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.fact_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 2. Integridad referencial: fact_sessions -> dim_date
SELECT 
  'olap_fact_sessions_dim_date_integrity' AS assertion_name,
  COUNT(*) AS orphan_sessions,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_date` dd ON fs.date_key = dd.date_key
WHERE fs.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND dd.date_key IS NULL;

-- 3. Integridad referencial: fact_sessions -> dim_device
SELECT 
  'olap_fact_sessions_dim_device_integrity' AS assertion_name,
  COUNT(*) AS orphan_sessions,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_device` dd ON fs.device_key = dd.device_key
WHERE fs.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND dd.device_key IS NULL;

-- 4. Integridad referencial: fact_sessions -> dim_geo
SELECT 
  'olap_fact_sessions_dim_geo_integrity' AS assertion_name,
  COUNT(*) AS orphan_sessions,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_geo` dg ON fs.geo_key = dg.geo_key
WHERE fs.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND dg.geo_key IS NULL;

-- 5. Integridad referencial: fact_sessions -> dim_channel
SELECT 
  'olap_fact_sessions_dim_channel_integrity' AS assertion_name,
  COUNT(*) AS orphan_sessions,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_channel` dc ON fs.channel_key = dc.channel_key
WHERE fs.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND dc.channel_key IS NULL;

-- 6. Consistencia: fact_sessions debe tener mismo volumen que stg_sessions
SELECT 
  'olap_fact_sessions_consistency' AS assertion_name,
  (SELECT COUNT(*) FROM `PROJECT_ID.olap.fact_sessions` 
   WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS fact_count,
  (SELECT COUNT(*) FROM `PROJECT_ID.stage_ga4.stg_sessions` 
   WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS stage_count,
  CASE 
    WHEN ABS((SELECT COUNT(*) FROM `PROJECT_ID.olap.fact_sessions` 
              WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) -
             (SELECT COUNT(*) FROM `PROJECT_ID.stage_ga4.stg_sessions` 
              WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))) <= 5
    THEN 'PASS' 
    ELSE 'FAIL' 
  END AS status;

-- 7. Dimensiones no vacías
SELECT 
  'olap_dimensions_not_empty' AS assertion_name,
  (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_date`) AS dim_date_count,
  (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_device`) AS dim_device_count,
  (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_geo`) AS dim_geo_count,
  (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_channel`) AS dim_channel_count,
  CASE 
    WHEN (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_date`) > 0
     AND (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_device`) > 0
     AND (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_geo`) > 0
     AND (SELECT COUNT(*) FROM `PROJECT_ID.olap.dim_channel`) > 0
    THEN 'PASS' 
    ELSE 'FAIL' 
  END AS status;

-- 8. Unicidad de claves en dimensiones
SELECT 
  'olap_dim_date_unique_keys' AS assertion_name,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT date_key) AS unique_keys,
  CASE WHEN COUNT(*) = COUNT(DISTINCT date_key) THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.dim_date`;

SELECT 
  'olap_dim_device_unique_keys' AS assertion_name,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT device_key) AS unique_keys,
  CASE WHEN COUNT(*) = COUNT(DISTINCT device_key) THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.olap.dim_device`;
