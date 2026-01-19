# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added
- Pipeline inicial GA4 → BigQuery → OLAP
- Scripts SQL de transformación (STAGE y OLAP)
- DAGs de Airflow para orquestación
- Data Quality checks y assertions
- Monitoreo y auditoría
- Guías de despliegue y versionado

### Changed

### Fixed

### Deprecated

### Removed

### Security

---

## [1.0.0] - 2024-01-XX

### Added
- Estructura inicial del repositorio
- Scripts SQL para STAGE: stg_events_flat, stg_sessions, stg_users
- Dimensiones OLAP: dim_date, dim_device, dim_geo, dim_campaign, dim_channel, dim_event_type
- Hechos OLAP: fact_sessions, fact_conversions, fact_events
- Views/Marts: mart_sessions, mart_conversions
- DAGs de Airflow: ga4_pipeline, data_quality_dag, audit_dag
- Configuración de Dataform
- Data Quality assertions (stage y olap)
- Monitoreo: etl_run_log, alerts, monitoring_queries
- Documentación completa:
  - README.md
  - docs/deployment.md
  - docs/partitioning_clustering_guide.md
  - docs/versioning_guide.md
  - setup/iam_setup.md
  - setup/ga4_bigquery_link.md

### Changed
- Todas las tablas implementadas con particionado por fecha (DATE)
- Clustering optimizado para cada tabla según patrones de uso

### Fixed

### Security
- Configuración de IAM y Service Accounts documentada
