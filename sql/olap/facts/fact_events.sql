-- =========================================================
-- OLAP: Hecho de Eventos (Opcional)
-- Tabla de hechos con grano de evento
-- Útil para análisis de funnels y pathing profundo
-- =========================================================

-- Primero crear la tabla si no existe
CREATE TABLE IF NOT EXISTS `PROJECT_ID.olap.fact_events`
(
  event_id STRING,
  event_date DATE,
  event_timestamp TIMESTAMP,
  session_id STRING,
  user_pseudo_id STRING,
  user_id STRING,
  
  -- Foreign keys
  date_key DATE,
  device_key STRING,
  geo_key STRING,
  campaign_key STRING,
  channel_key STRING,
  event_type_key STRING,
  
  -- Event info
  event_name STRING,
  page_location STRING,
  page_title STRING,
  
  -- Flags
  is_conversion_event BOOL,
  is_lead_event BOOL,
  
  -- Values
  conversion_value FLOAT64,
  purchase_revenue FLOAT64,
  
  -- Metadata
  _etl_timestamp TIMESTAMP
)
PARTITION BY event_date
CLUSTER BY session_id, event_name, event_timestamp;

-- MERGE incremental (ejecutar diariamente)
MERGE `PROJECT_ID.olap.fact_events` AS target
USING (
  SELECT
    -- Generar event_id único
    CONCAT(
      e.session_id,
      '_',
      CAST(e.event_timestamp AS STRING),
      '_',
      e.event_name
    ) AS event_id,
    
    DATE(e.event_timestamp_date) AS event_date,
    e.event_timestamp_date AS event_timestamp,
    e.session_id,
    e.user_pseudo_id,
    e.user_id,
    
    -- Foreign keys
    DATE(e.event_timestamp_date) AS date_key,
    d.device_key,
    g.geo_key,
    c.campaign_key,
    ch.channel_key,
    et.event_type_key,
    
    -- Event info
    e.event_name,
    e.page_location,
    e.page_title,
    
    -- Flags
    e.is_conversion_event,
    e.is_lead_event,
    
    -- Values
    CAST(e.conversion_value AS FLOAT64) AS conversion_value,
    e.purchase_revenue,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS _etl_timestamp
    
  FROM `PROJECT_ID.stage_ga4.stg_events_flat` e
  
  -- JOIN con dimensiones
  LEFT JOIN `PROJECT_ID.olap.dim_device` d
    ON COALESCE(e.device_category, 'unknown') = d.device_category
    AND COALESCE(e.device_os, 'unknown') = d.operating_system
  
  LEFT JOIN `PROJECT_ID.olap.dim_geo` g
    ON COALESCE(e.country, 'unknown') = g.country
    AND COALESCE(e.region, 'unknown') = g.region
    AND COALESCE(e.city, 'unknown') = g.city
  
  LEFT JOIN `PROJECT_ID.olap.dim_campaign` c
    ON COALESCE(e.utm_campaign, 'unknown') = c.utm_campaign
    AND COALESCE(e.utm_source, 'unknown') = c.utm_source
    AND COALESCE(e.utm_medium, 'unknown') = c.utm_medium
  
  LEFT JOIN `PROJECT_ID.olap.dim_channel` ch
    ON COALESCE(e.utm_source, e.traffic_source_source, 'unknown') = ch.source
    AND COALESCE(e.utm_medium, e.traffic_source_medium, 'unknown') = ch.medium
  
  LEFT JOIN `PROJECT_ID.olap.dim_event_type` et
    ON e.event_name = et.event_name
  
  WHERE e.event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
) AS source
ON target.event_id = source.event_id
WHEN MATCHED THEN
  UPDATE SET
    event_timestamp = source.event_timestamp,
    page_location = source.page_location,
    page_title = source.page_title,
    is_conversion_event = source.is_conversion_event,
    is_lead_event = source.is_lead_event,
    conversion_value = source.conversion_value,
    purchase_revenue = source.purchase_revenue,
    _etl_timestamp = source._etl_timestamp
WHEN NOT MATCHED THEN
  INSERT (
    event_id, event_date, event_timestamp, session_id, user_pseudo_id, user_id,
    date_key, device_key, geo_key, campaign_key, channel_key, event_type_key,
    event_name, page_location, page_title,
    is_conversion_event, is_lead_event,
    conversion_value, purchase_revenue,
    _etl_timestamp
  )
  VALUES (
    source.event_id, source.event_date, source.event_timestamp, source.session_id, 
    source.user_pseudo_id, source.user_id,
    source.date_key, source.device_key, source.geo_key, source.campaign_key, 
    source.channel_key, source.event_type_key,
    source.event_name, source.page_location, source.page_title,
    source.is_conversion_event, source.is_lead_event,
    source.conversion_value, source.purchase_revenue,
    source._etl_timestamp
  );

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.fact_events`
SET OPTIONS(
  description="Tabla de hechos de eventos. Grano: una fila por evento. Útil para análisis de funnels y pathing. Particionada por event_date, clusterizada por session_id, event_name y event_timestamp."
);
