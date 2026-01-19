-- =========================================================
-- OLAP: Hecho de Conversiones
-- Tabla de hechos con grano de conversión/lead
-- =========================================================

-- Primero crear la tabla si no existe
CREATE TABLE IF NOT EXISTS `PROJECT_ID.olap.fact_conversions`
(
  conversion_id STRING,
  conversion_date DATE,
  conversion_timestamp TIMESTAMP,
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
  
  -- Conversion info
  conversion_type STRING,  -- 'lead' o 'purchase'
  event_name STRING,
  lead_id STRING,
  
  -- Values
  conversion_value FLOAT64,
  purchase_revenue FLOAT64,
  
  -- Attribution (opcional)
  is_first_conversion BOOL,
  conversion_number INT64,  -- Número de conversión para este usuario
  
  -- Metadata
  _etl_timestamp TIMESTAMP
)
PARTITION BY conversion_date
CLUSTER BY date_key, channel_key, conversion_type;

-- MERGE incremental (ejecutar diariamente)
MERGE `PROJECT_ID.olap.fact_conversions` AS target
USING (
  WITH conversions AS (
    SELECT
      e.*,
      d.device_key,
      g.geo_key,
      c.campaign_key,
      ch.channel_key,
      et.event_type_key,
      ROW_NUMBER() OVER (
        PARTITION BY e.user_pseudo_id 
        ORDER BY e.event_timestamp_date
      ) AS conversion_number
    FROM `PROJECT_ID.stage_ga4.stg_events_flat` e
    
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
      AND (e.is_conversion_event = TRUE OR e.is_lead_event = TRUE)
  )
  
  SELECT
    -- Generar conversion_id único
    CONCAT(
      session_id,
      '_',
      CAST(event_timestamp_date AS STRING),
      '_',
      event_name
    ) AS conversion_id,
    
    DATE(event_timestamp_date) AS conversion_date,
    event_timestamp_date AS conversion_timestamp,
    session_id,
    user_pseudo_id,
    user_id,
    
    -- Foreign keys
    DATE(event_timestamp_date) AS date_key,
    device_key,
    geo_key,
    campaign_key,
    channel_key,
    event_type_key,
    
    -- Conversion info
    CASE 
      WHEN is_lead_event THEN 'lead'
      WHEN is_conversion_event THEN 'purchase'
      ELSE 'other'
    END AS conversion_type,
    event_name,
    lead_id,
    
    -- Values
    CAST(conversion_value AS FLOAT64) AS conversion_value,
    purchase_revenue,
    
    -- Attribution
    conversion_number = 1 AS is_first_conversion,
    conversion_number,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS _etl_timestamp
    
  FROM conversions
) AS source
ON target.conversion_id = source.conversion_id
WHEN MATCHED THEN
  UPDATE SET
    conversion_timestamp = source.conversion_timestamp,
    conversion_type = source.conversion_type,
    lead_id = source.lead_id,
    conversion_value = source.conversion_value,
    purchase_revenue = source.purchase_revenue,
    is_first_conversion = source.is_first_conversion,
    conversion_number = source.conversion_number,
    _etl_timestamp = source._etl_timestamp
WHEN NOT MATCHED THEN
  INSERT (
    conversion_id, conversion_date, conversion_timestamp, session_id, 
    user_pseudo_id, user_id,
    date_key, device_key, geo_key, campaign_key, channel_key, event_type_key,
    conversion_type, event_name, lead_id,
    conversion_value, purchase_revenue,
    is_first_conversion, conversion_number,
    _etl_timestamp
  )
  VALUES (
    source.conversion_id, source.conversion_date, source.conversion_timestamp, 
    source.session_id, source.user_pseudo_id, source.user_id,
    source.date_key, source.device_key, source.geo_key, source.campaign_key, 
    source.channel_key, source.event_type_key,
    source.conversion_type, source.event_name, source.lead_id,
    source.conversion_value, source.purchase_revenue,
    source.is_first_conversion, source.conversion_number,
    source._etl_timestamp
  );

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.fact_conversions`
SET OPTIONS(
  description="Tabla de hechos de conversiones. Grano: una fila por conversión/lead. Incluye atribución (primera conversión). Particionada por conversion_date, clusterizada por date_key, channel_key y conversion_type."
);
