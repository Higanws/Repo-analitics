-- =========================================================
-- OLAP: Hecho de Sesiones
-- Tabla de hechos con grano de sesión
-- =========================================================

-- Primero crear la tabla si no existe
CREATE TABLE IF NOT EXISTS `PROJECT_ID.olap.fact_sessions`
(
  session_id STRING,
  session_date DATE,
  user_pseudo_id STRING,
  user_id STRING,
  
  -- Foreign keys a dimensiones
  date_key DATE,
  device_key STRING,
  geo_key STRING,
  campaign_key STRING,
  channel_key STRING,
  
  -- Métricas de sesión
  session_start_timestamp TIMESTAMP,
  session_end_timestamp TIMESTAMP,
  session_duration_seconds INT64,
  events_count INT64,
  pageviews INT64,
  
  -- Flags
  has_conversion BOOL,
  has_lead BOOL,
  session_engaged INT64,
  
  -- Valores
  total_conversion_value FLOAT64,
  total_purchase_revenue FLOAT64,
  
  -- Landing/Exit pages
  landing_page STRING,
  exit_page STRING,
  
  -- Metadata
  _etl_timestamp TIMESTAMP
)
PARTITION BY session_date
CLUSTER BY date_key, channel_key, has_conversion;

-- MERGE incremental (ejecutar diariamente)
MERGE `PROJECT_ID.olap.fact_sessions` AS target
USING (
  SELECT
    s.session_id,
    s.session_date,
    s.user_pseudo_id,
    s.user_id,
    
    -- Foreign keys
    s.session_date AS date_key,
    d.device_key,
    g.geo_key,
    c.campaign_key,
    ch.channel_key,
    
    -- Métricas
    s.session_start_timestamp,
    s.session_end_timestamp,
    s.session_duration_seconds,
    s.events_count,
    s.pageviews,
    
    -- Flags
    CAST(s.has_conversion AS BOOL) AS has_conversion,
    CAST(s.has_lead AS BOOL) AS has_lead,
    s.session_engaged,
    
    -- Valores
    s.total_conversion_value,
    s.total_purchase_revenue,
    
    -- Pages
    s.landing_page,
    s.exit_page,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS _etl_timestamp
    
  FROM `PROJECT_ID.stage_ga4.stg_sessions` s
  
  -- JOIN con dimensiones
  LEFT JOIN `PROJECT_ID.olap.dim_device` d
    ON COALESCE(s.device_category, 'unknown') = d.device_category
    AND COALESCE(s.device_os, 'unknown') = d.operating_system
  
  LEFT JOIN `PROJECT_ID.olap.dim_geo` g
    ON COALESCE(s.country, 'unknown') = g.country
    AND COALESCE(s.region, 'unknown') = g.region
    AND COALESCE(s.city, 'unknown') = g.city
  
  LEFT JOIN `PROJECT_ID.olap.dim_campaign` c
    ON COALESCE(s.campaign, 'unknown') = c.utm_campaign
    AND COALESCE(s.source, 'unknown') = c.utm_source
    AND COALESCE(s.medium, 'unknown') = c.utm_medium
  
  LEFT JOIN `PROJECT_ID.olap.dim_channel` ch
    ON COALESCE(s.source, 'unknown') = ch.source
    AND COALESCE(s.medium, 'unknown') = ch.medium
  
  WHERE s.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
) AS source
ON target.session_id = source.session_id
WHEN MATCHED THEN
  UPDATE SET
    session_start_timestamp = source.session_start_timestamp,
    session_end_timestamp = source.session_end_timestamp,
    session_duration_seconds = source.session_duration_seconds,
    events_count = source.events_count,
    pageviews = source.pageviews,
    has_conversion = source.has_conversion,
    has_lead = source.has_lead,
    session_engaged = source.session_engaged,
    total_conversion_value = source.total_conversion_value,
    total_purchase_revenue = source.total_purchase_revenue,
    landing_page = source.landing_page,
    exit_page = source.exit_page,
    _etl_timestamp = source._etl_timestamp
WHEN NOT MATCHED THEN
  INSERT (
    session_id, session_date, user_pseudo_id, user_id,
    date_key, device_key, geo_key, campaign_key, channel_key,
    session_start_timestamp, session_end_timestamp, session_duration_seconds,
    events_count, pageviews, has_conversion, has_lead, session_engaged,
    total_conversion_value, total_purchase_revenue,
    landing_page, exit_page, _etl_timestamp
  )
  VALUES (
    source.session_id, source.session_date, source.user_pseudo_id, source.user_id,
    source.date_key, source.device_key, source.geo_key, source.campaign_key, source.channel_key,
    source.session_start_timestamp, source.session_end_timestamp, source.session_duration_seconds,
    source.events_count, source.pageviews, source.has_conversion, source.has_lead, source.session_engaged,
    source.total_conversion_value, source.total_purchase_revenue,
    source.landing_page, source.exit_page, source._etl_timestamp
  );

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.fact_sessions`
SET OPTIONS(
  description="Tabla de hechos de sesiones. Grano: una fila por sesión. Particionada por session_date, clusterizada por date_key, channel_key y has_conversion."
);
