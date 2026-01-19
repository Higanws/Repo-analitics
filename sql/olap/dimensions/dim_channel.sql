-- =========================================================
-- OLAP: Dimensión de Canal de Marketing
-- Tabla de dimensiones de canales (reglas de canalización)
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_channel`
AS
WITH channel_mapping AS (
  SELECT DISTINCT
    source,
    medium,
    campaign,
    -- Reglas de canalización (ajustar según necesidades)
    CASE
      -- Organic Search
      WHEN medium = 'organic' AND source IN ('google', 'bing', 'yahoo') THEN 'Organic Search'
      
      -- Paid Search
      WHEN medium IN ('cpc', 'ppc', 'paidsearch') THEN 'Paid Search'
      WHEN source IN ('google', 'bing') AND medium LIKE '%cpc%' THEN 'Paid Search'
      
      -- Social
      WHEN medium IN ('social', 'social-network', 'social-media', 'sm', 'social advertising') THEN 'Social'
      WHEN source IN ('facebook', 'instagram', 'twitter', 'linkedin', 'pinterest', 'tiktok') THEN 'Social'
      
      -- Email
      WHEN medium = 'email' THEN 'Email'
      
      -- Direct
      WHEN source = '(direct)' AND medium IN ('(none)', '(not set)') THEN 'Direct'
      
      -- Referral
      WHEN medium = 'referral' THEN 'Referral'
      
      -- Display
      WHEN medium IN ('display', 'banner', 'cpm') THEN 'Display'
      
      -- Other
      ELSE 'Other'
    END AS channel_group,
    
    CASE
      WHEN medium = 'organic' THEN 'Organic'
      WHEN medium IN ('cpc', 'ppc', 'paidsearch') THEN 'Paid'
      WHEN medium IN ('social', 'social-network') THEN 'Social'
      WHEN medium = 'email' THEN 'Email'
      WHEN medium = 'referral' THEN 'Referral'
      WHEN medium IN ('display', 'banner') THEN 'Display'
      ELSE 'Other'
    END AS channel_type
    
  FROM `PROJECT_ID.stage_ga4.stg_sessions`
  WHERE source IS NOT NULL OR medium IS NOT NULL
)

SELECT DISTINCT
  -- Generar channel_key único
  TO_HEX(SHA256(CONCAT(
    COALESCE(source, 'unknown'),
    '|',
    COALESCE(medium, 'unknown'),
    '|',
    COALESCE(channel_group, 'unknown')
  ))) AS channel_key,
  
  COALESCE(source, 'unknown') AS source,
  COALESCE(medium, 'unknown') AS medium,
  COALESCE(channel_group, 'Other') AS channel_group,
  COALESCE(channel_type, 'Other') AS channel_type,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM channel_mapping;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_channel`
SET OPTIONS(
  description="Dimensión de canales de marketing con reglas de canalización. Agrupa source/medium en canales estándar."
);
