-- =========================================================
-- OLAP: Dimensión de Geografía
-- Tabla de dimensiones geográficas
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_geo`
AS
SELECT DISTINCT
  -- Generar geo_key único
  TO_HEX(SHA256(CONCAT(
    COALESCE(country, 'unknown'),
    '|',
    COALESCE(region, 'unknown'),
    '|',
    COALESCE(city, 'unknown')
  ))) AS geo_key,
  
  -- Geografía
  COALESCE(continent, 'unknown') AS continent,
  COALESCE(country, 'unknown') AS country,
  COALESCE(region, 'unknown') AS region,
  COALESCE(city, 'unknown') AS city,
  
  -- Agrupaciones útiles
  CASE 
    WHEN country IN ('United States', 'Canada', 'Mexico') THEN 'North America'
    WHEN country IN ('Brazil', 'Argentina', 'Chile', 'Colombia') THEN 'Latin America'
    WHEN country IN ('Spain', 'United Kingdom', 'France', 'Germany', 'Italy') THEN 'Europe'
    WHEN country IN ('China', 'Japan', 'India', 'South Korea') THEN 'Asia'
    ELSE 'Other'
  END AS region_group,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE country IS NOT NULL;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_geo`
SET OPTIONS(
  description="Dimensión geográfica extraída de eventos GA4. Incluye continente, país, región y ciudad."
);
