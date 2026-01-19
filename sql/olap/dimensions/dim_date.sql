-- =========================================================
-- OLAP: Dimensión de Fecha (Calendario)
-- Tabla de dimensiones de fecha para análisis temporal
-- =========================================================

CREATE OR REPLACE TABLE `PROJECT_ID.olap.dim_date`
AS
WITH date_range AS (
  SELECT date_value
  FROM UNNEST(GENERATE_DATE_ARRAY('2020-01-01', '2030-12-31')) AS date_value
)

SELECT
  date_value AS date_key,
  date_value AS date_full,
  
  -- Año
  EXTRACT(YEAR FROM date_value) AS year,
  EXTRACT(ISOYEAR FROM date_value) AS iso_year,
  
  -- Trimestre
  EXTRACT(QUARTER FROM date_value) AS quarter,
  CONCAT('Q', CAST(EXTRACT(QUARTER FROM date_value) AS STRING)) AS quarter_name,
  CONCAT(CAST(EXTRACT(YEAR FROM date_value) AS STRING), '-Q', CAST(EXTRACT(QUARTER FROM date_value) AS STRING)) AS year_quarter,
  
  -- Mes
  EXTRACT(MONTH FROM date_value) AS month,
  FORMAT_DATE('%B', date_value) AS month_name,
  FORMAT_DATE('%b', date_value) AS month_name_short,
  CONCAT(CAST(EXTRACT(YEAR FROM date_value) AS STRING), '-', LPAD(CAST(EXTRACT(MONTH FROM date_value) AS STRING), 2, '0')) AS year_month,
  
  -- Semana
  EXTRACT(WEEK FROM date_value) AS week,
  EXTRACT(ISOWEEK FROM date_value) AS iso_week,
  DATE_TRUNC(date_value, WEEK) AS week_start_date,
  DATE_TRUNC(date_value, WEEK(MONDAY)) AS week_start_date_monday,
  
  -- Día
  EXTRACT(DAY FROM date_value) AS day,
  EXTRACT(DAYOFWEEK FROM date_value) AS day_of_week,
  FORMAT_DATE('%A', date_value) AS day_name,
  FORMAT_DATE('%a', date_value) AS day_name_short,
  EXTRACT(DAYOFYEAR FROM date_value) AS day_of_year,
  
  -- Flags
  CASE WHEN EXTRACT(DAYOFWEEK FROM date_value) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend,
  CASE WHEN date_value IN (
    SELECT holiday_date FROM UNNEST([
      DATE('2024-01-01'), DATE('2024-12-25'), DATE('2024-12-31')
      -- Agregar más feriados según necesidad
    ]) AS holiday_date
  ) THEN TRUE ELSE FALSE END AS is_holiday,
  
  -- Metadata
  CURRENT_TIMESTAMP() AS _etl_timestamp

FROM date_range;

-- Comentarios de tabla
ALTER TABLE `PROJECT_ID.olap.dim_date`
SET OPTIONS(
  description="Dimensión de fecha con calendario completo. Incluye año, trimestre, mes, semana, día y flags útiles para análisis."
);

-- Crear índice/cluster (no aplicable en BigQuery, pero documentar)
-- Esta tabla es pequeña y se puede hacer JOIN eficientemente
