-- =========================================================
-- MART: Vista lógica de Sesiones
-- Vista denormalizada para Looker Studio
-- =========================================================

CREATE OR REPLACE VIEW `PROJECT_ID.olap.mart_sessions`
AS
SELECT
  fs.session_id,
  fs.session_date,
  fs.user_pseudo_id,
  fs.user_id,
  
  -- Date dimensions
  dd.year,
  dd.quarter,
  dd.month,
  dd.week,
  dd.day_name,
  dd.is_weekend,
  
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
  
  -- Session metrics
  fs.session_start_timestamp,
  fs.session_end_timestamp,
  fs.session_duration_seconds,
  fs.events_count,
  fs.pageviews,
  fs.has_conversion,
  fs.has_lead,
  fs.session_engaged,
  fs.total_conversion_value,
  fs.total_purchase_revenue,
  fs.landing_page,
  fs.exit_page,
  
  -- Calculated metrics
  CASE WHEN fs.has_conversion THEN 1 ELSE 0 END AS conversions,
  CASE WHEN fs.has_lead THEN 1 ELSE 0 END AS leads,
  CASE WHEN fs.session_engaged > 0 THEN 1 ELSE 0 END AS engaged_sessions,
  
  -- Metadata
  fs._etl_timestamp

FROM `PROJECT_ID.olap.fact_sessions` fs
LEFT JOIN `PROJECT_ID.olap.dim_date` dd ON fs.date_key = dd.date_key
LEFT JOIN `PROJECT_ID.olap.dim_device` ddev ON fs.device_key = ddev.device_key
LEFT JOIN `PROJECT_ID.olap.dim_geo` dgeo ON fs.geo_key = dgeo.geo_key
LEFT JOIN `PROJECT_ID.olap.dim_campaign` dcamp ON fs.campaign_key = dcamp.campaign_key
LEFT JOIN `PROJECT_ID.olap.dim_channel` dchan ON fs.channel_key = dchan.channel_key;
