-- =========================================================
-- MART: Vista lógica de Conversiones
-- Vista denormalizada para Looker Studio
-- =========================================================

CREATE OR REPLACE VIEW `PROJECT_ID.olap.mart_conversions`
AS
SELECT
  fc.conversion_id,
  fc.conversion_date,
  fc.conversion_timestamp,
  fc.session_id,
  fc.user_pseudo_id,
  fc.user_id,
  
  -- Date dimensions
  dd.year,
  dd.quarter,
  dd.month,
  dd.week,
  dd.day_name,
  
  -- Device dimensions
  ddev.device_category,
  ddev.device_type_group,
  ddev.operating_system,
  
  -- Geo dimensions
  dgeo.country,
  dgeo.region,
  dgeo.city,
  dgeo.region_group,
  
  -- Campaign dimensions
  dcamp.utm_source,
  dcamp.utm_medium,
  dcamp.utm_campaign,
  dcamp.campaign_full_name,
  
  -- Channel dimensions
  dchan.channel_group,
  dchan.channel_type,
  dchan.source,
  dchan.medium,
  
  -- Conversion info
  fc.conversion_type,
  fc.event_name,
  fc.lead_id,
  fc.conversion_value,
  fc.purchase_revenue,
  fc.is_first_conversion,
  fc.conversion_number,
  
  -- Calculated metrics
  CASE WHEN fc.conversion_type = 'lead' THEN 1 ELSE 0 END AS leads,
  CASE WHEN fc.conversion_type = 'purchase' THEN 1 ELSE 0 END AS purchases,
  
  -- Metadata
  fc._etl_timestamp

FROM `PROJECT_ID.olap.fact_conversions` fc
LEFT JOIN `PROJECT_ID.olap.dim_date` dd ON fc.date_key = dd.date_key
LEFT JOIN `PROJECT_ID.olap.dim_device` ddev ON fc.device_key = ddev.device_key
LEFT JOIN `PROJECT_ID.olap.dim_geo` dgeo ON fc.geo_key = dgeo.geo_key
LEFT JOIN `PROJECT_ID.olap.dim_campaign` dcamp ON fc.campaign_key = dcamp.campaign_key
LEFT JOIN `PROJECT_ID.olap.dim_channel` dchan ON fc.channel_key = dchan.channel_key
LEFT JOIN `PROJECT_ID.olap.dim_event_type` det ON fc.event_type_key = det.event_type_key;
