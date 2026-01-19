-- =========================================================
-- STAGE: Aplanamiento de eventos GA4
-- Convierte eventos anidados en estructura plana y BI-friendly
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.stage_ga4.stg_events_flat`
PARTITION BY event_date_partition
CLUSTER BY event_name, user_pseudo_id, session_id
AS
WITH events_unnested AS (
  SELECT
    event_date,
    PARSE_TIMESTAMP('%Y%m%d', event_date) AS event_timestamp_date,
    DATE(PARSE_TIMESTAMP('%Y%m%d', event_date)) AS event_date_partition,
    event_timestamp,
    event_name,
    user_pseudo_id,
    user_id,
    
    -- Extraer ga_session_id de event_params
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    
    -- Page information
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title') AS page_title,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_referrer') AS page_referrer,
    
    -- UTM parameters
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'utm_source') AS utm_source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'utm_medium') AS utm_medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'utm_campaign') AS utm_campaign,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'utm_term') AS utm_term,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'utm_content') AS utm_content,
    
    -- Conversion / Lead events
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'lead_id') AS lead_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'conversion_value') AS conversion_value,
    
    -- Device information
    device.category AS device_category,
    device.mobile_brand_name AS device_mobile_brand,
    device.mobile_model_name AS device_mobile_model,
    device.operating_system AS device_os,
    device.operating_system_version AS device_os_version,
    
    -- Geography
    geo.country AS country,
    geo.region AS region,
    geo.city AS city,
    geo.continent AS continent,
    
    -- Traffic source
    traffic_source.name AS traffic_source_name,
    traffic_source.medium AS traffic_source_medium,
    traffic_source.source AS traffic_source_source,
    
    -- Session info
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
    
    -- Event value
    ecommerce.total_item_quantity AS total_item_quantity,
    ecommerce.purchase_revenue AS purchase_revenue,
    ecommerce.purchase_revenue_currency AS purchase_revenue_currency,
    
    -- Metadata
    _TABLE_SUFFIX AS table_suffix
    
  FROM `PROJECT_ID.analytics_PROPERTY_ID.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
                          AND FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
)

SELECT
  *,
  -- Generar session_id único
  CONCAT(user_pseudo_id, '_', CAST(ga_session_id AS STRING)) AS session_id,
  -- Extraer dominio de page_location
  REGEXP_EXTRACT(page_location, r'https?://([^/]+)') AS page_domain,
  -- Flag de evento de conversión
  CASE 
    WHEN event_name IN ('purchase', 'conversion', 'generate_lead') THEN TRUE
    ELSE FALSE
  END AS is_conversion_event,
  -- Flag de evento de lead
  CASE 
    WHEN event_name IN ('generate_lead', 'form_submit', 'contact') THEN TRUE
    ELSE FALSE
  END AS is_lead_event,
  CURRENT_TIMESTAMP() AS _etl_timestamp,
  event_date_partition

FROM events_unnested;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.stage_ga4.stg_events_flat`
SET OPTIONS(
  description="Tabla STAGE con eventos GA4 aplanados. Particionada por DATE(event_date), clusterizada por event_name, user_pseudo_id y session_id para optimizar queries por evento y usuario."
);
