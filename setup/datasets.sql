-- =========================================================
-- Script de creación de datasets en BigQuery
-- Ejecutar con permisos de BigQuery Admin
-- =========================================================

-- Dataset RAW (puede ser el nativo de GA4: analytics_<property_id>)
-- Si ya existe el dataset nativo de GA4, no es necesario crearlo
-- CREATE SCHEMA IF NOT EXISTS `PROJECT_ID.analytics_PROPERTY_ID`
-- OPTIONS(
--   description="Dataset RAW con exportación nativa de GA4",
--   location="US"
-- );

-- Dataset STAGE: datos normalizados y aplanados
CREATE SCHEMA IF NOT EXISTS `PROJECT_ID.stage_ga4`
OPTIONS(
  description="Dataset STAGE: eventos y sesiones normalizados de GA4",
  location="US"
);

-- Dataset OLAP: modelo estrella para BI
CREATE SCHEMA IF NOT EXISTS `PROJECT_ID.olap`
OPTIONS(
  description="Dataset OLAP: modelo estrella con dimensiones y hechos",
  location="US"
);

-- Dataset MONITORING: auditoría y logs
CREATE SCHEMA IF NOT EXISTS `PROJECT_ID.monitoring`
OPTIONS(
  description="Dataset para monitoreo, auditoría y logs del pipeline ETL",
  location="US"
);

-- Reemplazar PROJECT_ID con tu Project ID de GCP
-- Ejemplo: `my-project.stage_ga4`
