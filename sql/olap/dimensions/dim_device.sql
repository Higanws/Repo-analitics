-- =========================================================
-- OLAP: Dimensión de Dispositivo
-- Tabla de dimensiones de dispositivos
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_device`
AS
SELECT DISTINCT
  -- Generar device_key único
  TO_HEX(SHA256(CONCAT(
    COALESCE(device_category, 'unknown'),
    '|',
    COALESCE(device_os, 'unknown'),
    '|',
    COALESCE(device_mobile_brand, 'unknown')
  ))) AS device_key,
  
  -- Categoría
  COALESCE(device_category, 'unknown') AS device_category,
  
  -- Mobile info
  COALESCE(device_mobile_brand, 'unknown') AS mobile_brand,
  COALESCE(device_mobile_model, 'unknown') AS mobile_model,
  
  -- OS
  COALESCE(device_os, 'unknown') AS operating_system,
  COALESCE(device_os_version, 'unknown') AS operating_system_version,
  
  -- Agrupaciones útiles
  CASE 
    WHEN device_category = 'mobile' THEN 'Mobile'
    WHEN device_category = 'tablet' THEN 'Tablet'
    WHEN device_category = 'desktop' THEN 'Desktop'
    ELSE 'Other'
  END AS device_type_group,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE device_category IS NOT NULL;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_device`
SET OPTIONS(
  description="Dimensión de dispositivos extraída de eventos GA4. Incluye categoría, marca, modelo y sistema operativo."
);
