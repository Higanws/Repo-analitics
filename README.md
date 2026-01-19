# Repositorio Analytics - GA4 → BigQuery → OLAP → Looker Studio

Pipeline de datos end-to-end para analítica web usando Google Analytics 4, BigQuery y Looker Studio.

## Arquitectura

```
GA4 → BigQuery (RAW) → BigQuery (STAGE) → BigQuery (OLAP) → Looker Studio
```

### Capas de Datos

1. **RAW**: Datos nativos exportados desde GA4 (`analytics_<property_id>`)
2. **STAGE**: Datos normalizados y aplanados (`stage_ga4`)
3. **OLAP**: Modelo estrella para BI (`olap`)

## Stack Tecnológico

- **Tracking**: Google Analytics 4 (GA4) + Google Tag Manager (GTM)
- **Data Platform**: BigQuery
- **Transformaciones**: Dataform
- **Orquestación**: Cloud Composer (Airflow)
- **BI**: Looker Studio
- **Monitoreo**: Cloud Logging + Data Quality Checks

## Estructura del Proyecto

```
├── setup/              # Scripts de configuración inicial
├── sql/                # Scripts SQL puros (stage, olap, views)
├── dataform/           # Transformaciones versionadas con Dataform
├── airflow/            # DAGs de orquestación
├── data_quality/       # Validaciones y assertions
├── monitoring/         # Auditoría y alertas
├── looker_studio/      # Configuración de dashboards
└── docs/               # Documentación del proyecto
```

## Setup Inicial

### Prerrequisitos

1. Cuenta de Google Cloud Platform con BigQuery habilitado
2. Google Analytics 4 configurado
3. Cloud Composer (Airflow) o Cloud Workflows
4. Python 3.8+ (para Airflow)

### Instalación

1. **Configurar GA4 → BigQuery Link**
   - Ver guía en `setup/ga4_bigquery_link.md`

2. **Crear Datasets en BigQuery**
   ```bash
   # Ejecutar scripts en setup/datasets.sql
   ```

3. **Configurar IAM**
   - Ver `setup/iam_setup.md` para roles y service accounts

4. **Instalar Dependencias**
   ```bash
   pip install -r requirements.txt
   ```

5. **Configurar Dataform**
   ```bash
   cd dataform
   # Seguir configuración en dataform/dataform.json
   ```

6. **Desplegar DAGs de Airflow**
   - Copiar `airflow/dags/` a tu bucket de Cloud Composer

## Fases de Desarrollo

### Fase 1: RAW (1 día)
- Link GA4 → BigQuery
- Validar exportación de eventos
- Crear datasets destino

### Fase 2: STAGE (1-2 días)
- Aplanar eventos (`stg_events_flat`)
- Sessionization (`stg_sessions`)

### Fase 3: OLAP (2-4 días)
- Dimensiones (date, device, geo, campaign, channel)
- Hechos (sessions, conversions)

### Fase 4: BI (1-2 días)
- Configurar Looker Studio
- Crear dashboards

### Fase 5: Operación (1-3 días)
- Incremental processing
- Auditoría y alertas
- Optimización de costos

## Uso

### Ejecutar Transformaciones Manualmente

```sql
-- Ejecutar scripts en orden:
-- 1. sql/stage/stg_events_flat.sql
-- 2. sql/stage/stg_sessions.sql
-- 3. sql/olap/dimensions/*.sql
-- 4. sql/olap/facts/*.sql
```

### Ejecutar con Dataform

```bash
dataform run
```

### Monitorear Pipeline

```sql
-- Ver últimas ejecuciones
SELECT * FROM monitoring.etl_run_log 
ORDER BY run_timestamp DESC 
LIMIT 10;
```

## Documentación

- [Guía de Despliegue](docs/deployment.md) - Pasos para desplegar en GCP
- [Guía de Versionado](docs/versioning_guide.md) - Git y Dataform para versionado
- [Guía de Particionado y Clustering](docs/partitioning_clustering_guide.md) - Optimización de tablas

## Versionado

Este proyecto usa:
- **Git** para versionado de código (SQL, DAGs, configuración)
- **Dataform** (opcional) para gestión de dependencias SQL

Ver [Guía de Versionado](docs/versioning_guide.md) para detalles completos.

## Contribución

Ver `docs/versioning_guide.md` para flujo de trabajo y convenciones de commits.

## Licencia

[Especificar licencia]
