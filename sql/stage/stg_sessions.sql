-- =========================================================
-- STAGE: Sessionization
-- Agrega eventos por sesión (user_pseudo_id + ga_session_id)
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.stage_ga4.stg_sessions`
PARTITION BY session_date
CLUSTER BY session_id, source, medium, has_conversion
AS
SELECT
  session_id,
  user_pseudo_id,
  user_id,
  ga_session_id,
  DATE(event_timestamp_date) AS session_date,
  
  -- Timestamps de sesión
  MIN(event_timestamp_date) AS session_start_timestamp,
  MAX(event_timestamp_date) AS session_end_timestamp,
  TIMESTAMP_DIFF(MAX(event_timestamp_date), MIN(event_timestamp_date), SECOND) AS session_duration_seconds,
  
  -- Conteos
  COUNT(*) AS events_count,
  COUNT(DISTINCT event_name) AS unique_events_count,
  COUNTIF(event_name = 'page_view') AS pageviews,
  COUNTIF(event_name = 'scroll') AS scrolls,
  
  -- Flags de conversión
  MAX(is_conversion_event) AS has_conversion,
  MAX(is_lead_event) AS has_lead,
  COUNTIF(is_conversion_event) AS conversion_events_count,
  COUNTIF(is_lead_event) AS lead_events_count,
  
  -- Valores de conversión
  SUM(CAST(conversion_value AS FLOAT64)) AS total_conversion_value,
  MAX(purchase_revenue) AS max_purchase_revenue,
  SUM(purchase_revenue) AS total_purchase_revenue,
  
  -- Primera y última página
  ARRAY_AGG(page_location ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS landing_page,
  ARRAY_AGG(page_location ORDER BY event_timestamp DESC LIMIT 1)[OFFSET(0)] AS exit_page,
  
  -- Device (tomar el más frecuente)
  ARRAY_AGG(device_category ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS device_category,
  ARRAY_AGG(device_os ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS device_os,
  
  -- Geography (tomar el más frecuente)
  ARRAY_AGG(country ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS country,
  ARRAY_AGG(region ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS region,
  ARRAY_AGG(city ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS city,
  
  -- Traffic source (UTMs o traffic_source)
  COALESCE(
    ARRAY_AGG(utm_source ORDER BY event_timestamp LIMIT 1)[OFFSET(0)],
    ARRAY_AGG(traffic_source_source ORDER BY event_timestamp LIMIT 1)[OFFSET(0)]
  ) AS source,
  COALESCE(
    ARRAY_AGG(utm_medium ORDER BY event_timestamp LIMIT 1)[OFFSET(0)],
    ARRAY_AGG(traffic_source_medium ORDER BY event_timestamp LIMIT 1)[OFFSET(0)]
  ) AS medium,
  ARRAY_AGG(utm_campaign ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS campaign,
  ARRAY_AGG(utm_term ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS term,
  ARRAY_AGG(utm_content ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS content,
  
  -- Session engagement
  MAX(session_engaged) AS session_engaged,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
GROUP BY
  session_id,
  user_pseudo_id,
  user_id,
  ga_session_id,
  DATE(event_timestamp_date);

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.stage_ga4.stg_sessions`
SET OPTIONS(
  description="Tabla STAGE con sesiones agregadas. Particionada por session_date (DATE), clusterizada por session_id, source, medium y has_conversion para optimizar queries por sesión y canal."
);
