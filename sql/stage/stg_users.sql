-- =========================================================
-- STAGE: Agregados por Usuario (Opcional)
-- Vista agregada por user_pseudo_id para análisis de usuarios
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.stage_ga4.stg_users`
PARTITION BY user_first_seen_date
CLUSTER BY user_pseudo_id, primary_country, primary_device_category
AS
SELECT
  user_pseudo_id,
  user_id,
  
  -- Fechas
  MIN(session_date) AS user_first_seen_date,
  MAX(session_date) AS user_last_seen_date,
  DATE_DIFF(MAX(session_date), MIN(session_date), DAY) AS user_lifetime_days,
  
  -- Conteos agregados
  COUNT(DISTINCT session_id) AS total_sessions,
  SUM(events_count) AS total_events,
  SUM(pageviews) AS total_pageviews,
  
  -- Conversiones
  SUM(has_conversion) AS total_conversions,
  SUM(has_lead) AS total_leads,
  SUM(total_conversion_value) AS total_user_conversion_value,
  SUM(total_purchase_revenue) AS total_user_purchase_revenue,
  
  -- Engagement
  AVG(session_duration_seconds) AS avg_session_duration_seconds,
  SUM(session_engaged) AS total_engaged_sessions,
  
  -- Device más usado
  ARRAY_AGG(device_category ORDER BY session_date LIMIT 1)[OFFSET(0)] AS primary_device_category,
  
  -- País más frecuente
  ARRAY_AGG(country ORDER BY session_date LIMIT 1)[OFFSET(0)] AS primary_country,
  
  -- Canal más usado
  ARRAY_AGG(source ORDER BY session_date LIMIT 1)[OFFSET(0)] AS primary_source,
  ARRAY_AGG(medium ORDER BY session_date LIMIT 1)[OFFSET(0)] AS primary_medium,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)  -- Últimos 90 días
GROUP BY
  user_pseudo_id,
  user_id;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.stage_ga4.stg_users`
SET OPTIONS(
  description="Tabla STAGE con agregados por usuario. Útil para análisis de cohortes y comportamiento de usuarios."
);
