-- =========================================================
-- Data Quality Assertions - STAGE
-- Validaciones sobre las tablas de STAGE
-- =========================================================

-- 1. Volumen de eventos diario (debe ser > 0)
SELECT 
  'stage_events_volume' AS assertion_name,
  COUNT(*) AS events_count,
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY));

-- 2. Eventos sin ga_session_id (debe ser mínimo)
SELECT 
  'stage_events_missing_session_id' AS assertion_name,
  COUNT(*) AS events_without_session,
  CASE WHEN COUNT(*) < (SELECT COUNT(*) * 0.01 FROM `PROJECT_ID.stage_ga4.stg_events_flat` 
                        WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)))
       THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  AND ga_session_id IS NULL;

-- 3. Volumen de sesiones diario (debe ser > 0)
SELECT 
  'stage_sessions_volume' AS assertion_name,
  COUNT(*) AS sessions_count,
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 4. Sesiones con duración negativa (no debe haber)
SELECT 
  'stage_sessions_negative_duration' AS assertion_name,
  COUNT(*) AS sessions_negative_duration,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND session_duration_seconds < 0;

-- 5. Distribución de eventos por sesión (validar outliers)
SELECT 
  'stage_sessions_events_distribution' AS assertion_name,
  AVG(events_count) AS avg_events_per_session,
  STDDEV(events_count) AS stddev_events_per_session,
  CASE WHEN AVG(events_count) BETWEEN 1 AND 1000 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 6. Unicidad de session_id
SELECT 
  'stage_sessions_unique' AS assertion_name,
  COUNT(*) AS total_sessions,
  COUNT(DISTINCT session_id) AS unique_sessions,
  CASE WHEN COUNT(*) = COUNT(DISTINCT session_id) THEN 'PASS' ELSE 'FAIL' END AS status
FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 7. Campos críticos no nulos
SELECT 
  'stage_events_critical_fields' AS assertion_name,
  COUNT(*) AS total_events,
  COUNTIF(event_name IS NULL) AS null_event_name,
  COUNTIF(user_pseudo_id IS NULL) AS null_user_id,
  COUNTIF(event_timestamp IS NULL) AS null_timestamp,
  CASE 
    WHEN COUNTIF(event_name IS NULL) = 0 
     AND COUNTIF(user_pseudo_id IS NULL) = 0 
     AND COUNTIF(event_timestamp IS NULL) = 0 
    THEN 'PASS' 
    ELSE 'FAIL' 
  END AS status
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY));
