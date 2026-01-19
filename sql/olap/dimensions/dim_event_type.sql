-- =========================================================
-- OLAP: Dimensión de Tipo de Evento (Opcional)
-- Tabla de dimensiones de tipos de eventos
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_event_type`
AS
SELECT DISTINCT
  -- Generar event_type_key único
  TO_HEX(SHA256(event_name)) AS event_type_key,
  
  event_name,
  
  -- Categorización de eventos
  CASE
    WHEN event_name IN ('page_view', 'view_item', 'view_item_list') THEN 'View'
    WHEN event_name IN ('click', 'select_content', 'file_download') THEN 'Engagement'
    WHEN event_name IN ('generate_lead', 'form_submit', 'contact') THEN 'Lead'
    WHEN event_name IN ('purchase', 'conversion', 'add_to_cart', 'begin_checkout') THEN 'Conversion'
    WHEN event_name IN ('search', 'view_search_results') THEN 'Search'
    WHEN event_name IN ('scroll', 'video_start', 'video_progress') THEN 'Engagement'
    ELSE 'Other'
  END AS event_category,
  
  CASE
    WHEN event_name IN ('generate_lead', 'purchase', 'conversion') THEN TRUE
    ELSE FALSE
  END AS is_conversion_event,
  
  CASE
    WHEN event_name IN ('generate_lead', 'form_submit', 'contact') THEN TRUE
    ELSE FALSE
  END AS is_lead_event,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_name IS NOT NULL;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_event_type`
SET OPTIONS(
  description="Dimensión de tipos de eventos. Categoriza eventos GA4 y marca eventos de conversión y leads."
);
