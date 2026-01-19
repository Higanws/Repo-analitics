# Guía de Particionado y Clustering en BigQuery

Esta guía explica cómo está implementado el particionado y clustering (índices) en las tablas del proyecto.

## Conceptos

### Particionado (Partitioning)

El particionado divide una tabla en segmentos basados en una columna de fecha. Esto permite:
- **Reducir costos**: Solo se escanean las particiones relevantes
- **Mejorar performance**: Queries más rápidas al filtrar por partición
- **Facilitar mantenimiento**: Eliminar particiones antiguas fácilmente

### Clustering (Índices)

El clustering organiza los datos dentro de cada partición basándose en columnas específicas. Esto permite:
- **Optimizar JOINs**: Datos relacionados están cerca
- **Mejorar filtros**: Queries con filtros en columnas clusterizadas son más eficientes
- **Reducir escaneo**: Menos datos procesados en queries comunes

## Implementación en el Proyecto

### Tablas STAGE

#### `stg_events_flat`

```sql
PARTITION BY event_date_partition  -- DATE
CLUSTER BY event_name, user_pseudo_id, session_id
```

**Particionado:**
- Campo: `event_date_partition` (tipo DATE, derivado de `event_date` STRING)
- Una partición por día
- Permite filtrar eficientemente por rango de fechas

**Clustering:**
- `event_name`: Optimiza queries por tipo de evento
- `user_pseudo_id`: Optimiza análisis por usuario
- `session_id`: Optimiza análisis por sesión

**Ejemplo de query optimizada:**
```sql
SELECT *
FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition BETWEEN '2024-01-01' AND '2024-01-07'  -- Solo escanea 7 particiones
  AND event_name = 'page_view'  -- Beneficia del clustering
  AND user_pseudo_id = 'user123'  -- Beneficia del clustering
```

#### `stg_sessions`

```sql
PARTITION BY session_date  -- DATE
CLUSTER BY session_id, source, medium, has_conversion
```

**Particionado:**
- Campo: `session_date` (tipo DATE)
- Una partición por día

**Clustering:**
- `session_id`: Búsquedas por sesión específica
- `source`: Análisis por fuente de tráfico
- `medium`: Análisis por medio
- `has_conversion`: Filtros por conversión

#### `stg_users`

```sql
PARTITION BY user_first_seen_date  -- DATE
CLUSTER BY user_pseudo_id, primary_country, primary_device_category
```

**Particionado:**
- Campo: `user_first_seen_date` (tipo DATE)
- Particionado por fecha de primer contacto

**Clustering:**
- `user_pseudo_id`: Búsquedas por usuario
- `primary_country`: Análisis geográfico
- `primary_device_category`: Análisis por dispositivo

### Tablas OLAP

#### `fact_sessions`

```sql
PARTITION BY session_date  -- DATE
CLUSTER BY date_key, channel_key, has_conversion
```

**Particionado:**
- Campo: `session_date` (tipo DATE)

**Clustering:**
- `date_key`: JOINs con `dim_date`
- `channel_key`: JOINs con `dim_channel` y análisis por canal
- `has_conversion`: Filtros por conversión (muy común)

#### `fact_events`

```sql
PARTITION BY event_date  -- DATE
CLUSTER BY session_id, event_name, event_timestamp
```

**Particionado:**
- Campo: `event_date` (tipo DATE)

**Clustering:**
- `session_id`: Análisis de funnels y pathing
- `event_name`: Filtros por tipo de evento
- `event_timestamp`: Ordenamiento temporal

#### `fact_conversions`

```sql
PARTITION BY conversion_date  -- DATE
CLUSTER BY date_key, channel_key, conversion_type
```

**Particionado:**
- Campo: `conversion_date` (tipo DATE)

**Clustering:**
- `date_key`: JOINs con `dim_date`
- `channel_key`: Análisis de atribución por canal
- `conversion_type`: Diferenciar leads vs purchases

### Tablas de Dimensiones

Las tablas de dimensiones son pequeñas y no requieren particionado, pero pueden beneficiarse de clustering:

- `dim_date`: No necesita clustering (tabla pequeña, ~3650 filas para 10 años)
- `dim_device`: Clustering opcional por `device_key`
- `dim_geo`: Clustering opcional por `geo_key`
- `dim_campaign`: Clustering opcional por `campaign_key`
- `dim_channel`: Clustering opcional por `channel_key`

## Mejores Prácticas

### 1. Siempre Filtrar por Partición

```sql
-- BUENO: Filtra por partición
SELECT * FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition = '2024-01-15'

-- MALO: No filtra por partición (escanea todas las particiones)
SELECT * FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_timestamp_date >= '2024-01-15'
```

### 2. Usar Rangos de Particiones

```sql
-- BUENO: Rango de particiones
WHERE event_date_partition BETWEEN '2024-01-01' AND '2024-01-31'

-- MALO: Función en columna de partición
WHERE DATE(event_timestamp_date) BETWEEN '2024-01-01' AND '2024-01-31'
```

### 3. Ordenar por Columnas Clusterizadas

```sql
-- BUENO: Ordena por columna clusterizada
ORDER BY event_name, user_pseudo_id

-- MALO: Ordena por columna no clusterizada
ORDER BY page_location
```

### 4. JOINs con Claves Clusterizadas

```sql
-- BUENO: JOIN por clave clusterizada
SELECT *
FROM fact_sessions fs
JOIN dim_channel dc ON fs.channel_key = dc.channel_key

-- MALO: JOIN por campos no clusterizados
SELECT *
FROM fact_sessions fs
JOIN dim_channel dc ON fs.source = dc.source AND fs.medium = dc.medium
```

## Monitoreo y Optimización

### Verificar Tamaño de Particiones

```sql
SELECT
  table_name,
  partition_id,
  ROUND(total_logical_bytes / POW(10, 9), 2) AS size_gb,
  total_rows
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'stg_events_flat'
ORDER BY partition_id DESC
LIMIT 10;
```

**Recomendaciones:**
- Tamaño ideal: 0.5 - 2 GB por partición
- < 0.5 GB: Considerar consolidar (ej: partición mensual)
- > 2 GB: Considerar subparticionar o ajustar clustering

### Verificar Efectividad del Clustering

```sql
SELECT
  job_id,
  total_bytes_processed,
  total_bytes_billed,
  CASE
    WHEN total_bytes_processed < total_bytes_billed * 0.5 THEN 'Clustering efectivo'
    ELSE 'Clustering no efectivo'
  END AS clustering_effectiveness
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND statement_type = 'SELECT'
ORDER BY total_bytes_processed DESC
LIMIT 10;
```

### Verificar Uso de Particiones

```sql
-- Ver qué particiones se están usando en queries
SELECT
  DATE(creation_time) AS query_date,
  COUNT(*) AS query_count,
  COUNT(DISTINCT REGEXP_EXTRACT(query, r'event_date_partition\s*=\s*[\'"]?([^\'"]+)')) AS unique_partitions_queried
FROM `PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND query LIKE '%stg_events_flat%'
GROUP BY query_date
ORDER BY query_date DESC;
```

## Mantenimiento

### Eliminar Particiones Antiguas

```sql
-- Eliminar datos de más de 2 años
DELETE FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

-- Verificar espacio liberado
SELECT
  ROUND(SUM(total_logical_bytes) / POW(10, 12), 2) AS total_tb
FROM `PROJECT_ID.stage_ga4.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'stg_events_flat';
```

### Recrear Tabla con Nuevo Clustering

Si necesitas cambiar el clustering (BigQuery no permite alterarlo):

```sql
-- 1. Crear nueva tabla con clustering actualizado
CREATE OR REPLACE TABLE `PROJECT_ID.stage_ga4.stg_events_flat_new`
PARTITION BY event_date_partition
CLUSTER BY event_name, user_pseudo_id, session_id, page_domain  -- Nuevo clustering
AS
SELECT * FROM `PROJECT_ID.stage_ga4.stg_events_flat`;

-- 2. Verificar datos
SELECT COUNT(*) FROM `PROJECT_ID.stage_ga4.stg_events_flat_new`;

-- 3. Reemplazar tabla original
DROP TABLE `PROJECT_ID.stage_ga4.stg_events_flat`;
ALTER TABLE `PROJECT_ID.stage_ga4.stg_events_flat_new`
RENAME TO `stg_events_flat`;
```

## Costos y Beneficios

### Ahorro de Costos

- **Sin particionado**: Query sobre 1 año = escanear ~365 particiones = ~365 GB
- **Con particionado**: Query sobre 7 días = escanear 7 particiones = ~7 GB
- **Ahorro**: ~98% de reducción en bytes escaneados

### Mejora de Performance

- **Sin clustering**: JOIN con dim_channel escanea toda la tabla
- **Con clustering**: JOIN escanea solo datos relevantes
- **Mejora**: 50-90% de reducción en tiempo de ejecución

## Referencias

- [Documentación BigQuery Partitioning](https://cloud.google.com/bigquery/docs/partitioned-tables)
- [Documentación BigQuery Clustering](https://cloud.google.com/bigquery/docs/clustered-tables)
- [Best Practices](https://cloud.google.com/bigquery/docs/best-practices-performance-overview)
