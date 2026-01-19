-- =========================================================
-- OLAP: Dimensión de Campaña
-- Tabla de dimensiones de campañas (UTMs)
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_campaign`
AS
SELECT DISTINCT
  -- Generar campaign_key único
  TO_HEX(SHA256(CONCAT(
    COALESCE(utm_source, 'unknown'),
    '|',
    COALESCE(utm_medium, 'unknown'),
    '|',
    COALESCE(utm_campaign, 'unknown'),
    '|',
    COALESCE(utm_term, 'unknown'),
    '|',
    COALESCE(utm_content, 'unknown')
  ))) AS campaign_key,
  
  -- UTM parameters
  COALESCE(utm_source, 'unknown') AS utm_source,
  COALESCE(utm_medium, 'unknown') AS utm_medium,
  COALESCE(utm_campaign, 'unknown') AS utm_campaign,
  COALESCE(utm_term, 'unknown') AS utm_term,
  COALESCE(utm_content, 'unknown') AS utm_content,
  
  -- Campaña completa
  CONCAT(
    COALESCE(utm_source, 'unknown'), ' / ',
    COALESCE(utm_medium, 'unknown'), ' / ',
    COALESCE(utm_campaign, 'unknown')
  ) AS campaign_full_name,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE utm_source IS NOT NULL 
   OR utm_medium IS NOT NULL 
   OR utm_campaign IS NOT NULL;

-- Si no hay campañas, crear registro por defecto
INSERT INTO `PROJECT_ID.olap.dim_campaign` (
  campaign_key,
  utm_source,
  utm_medium,
  utm_campaign,
  utm_term,
  utm_content,
  campaign_full_name,
  _etl_timestamp
)
SELECT
  TO_HEX(SHA256('unknown|unknown|unknown|unknown|unknown')) AS campaign_key,
  'unknown' AS utm_source,
  'unknown' AS utm_medium,
  'unknown' AS utm_campaign,
  'unknown' AS utm_term,
  'unknown' AS utm_content,
  'unknown / unknown / unknown' AS campaign_full_name,
  CURRENT_TIMESTAMP() AS _etl_timestamp
WHERE NOT EXISTS (
  SELECT 1 FROM `PROJECT_ID.olap.dim_campaign` 
  WHERE campaign_key = TO_HEX(SHA256('unknown|unknown|unknown|unknown|unknown'))
);

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_campaign`
SET OPTIONS(
  description="Dimensión de campañas basada en parámetros UTM. Incluye source, medium, campaign, term y content."
);
