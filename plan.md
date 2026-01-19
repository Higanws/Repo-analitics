Stack (GA4 → BigQuery → OLAP → Looker Studio)
Tracking / Analytics

Google Analytics 4 (GA4) (event-based)

Google Tag Manager (GTM) o gtag.js (implementación de eventos, UTMs, gclid en forms)

Ingesta

GA4 → BigQuery Link (export nativo a tablas events_YYYYMMDD)

(Opcional) Google Ads → BigQuery Data Transfer Service (costos/clicks/impresiones) (si más adelante lo piden)

Data Platform (en BigQuery)

Datasets por capa

raw_ga4 (o dataset nativo analytics_<property_id>)

stage_ga4

olap

BigQuery SQL (CTAS/MERGE, particionado, clustering)

Dataform (recomendado) o dbt para versionado y DAG de SQL

(Alternativa) Cloud Composer (Airflow) si la org ya lo usa

Orquestación / Operación

Cloud Scheduler (trigger)

Workflows (si no usan Airflow) o Composer

Cloud Logging + Monitoring

(Opcional) BigQuery Data Quality checks: queries/assertions + tablas de auditoría

Gobierno / Seguridad

IAM / Service Accounts

(Opcional) RLS/CLS en BigQuery

(Opcional) Data Catalog / tags

BI

Looker Studio (dashboards)

(Opcional) Looker / LookML si existe (semantic layer), aunque vos dijiste que los marts se arman ahí

Plan de desarrollo (iterativo, “de entrevista”)
Fase 0 — Alineación (0.5–1 día)

Deliverables

Definición de KPIs (sessions, leads, conversion, CPL/CPA si hay costos, etc.)

Lista de eventos GA4 relevantes (lead events, conversion events)

Convención de nombres + capas + datasets

Fase 1 — RAW listo (1 día)

Objetivo: tener GA4 exportando a BigQuery y gobernanza mínima.

Link GA4→BigQuery

Validar que llegan events_* diarios

Crear datasets destino: stage_ga4, olap

IAM mínimo: acceso lectura raw, escritura stage/olap

Checklist

¿Se exporta todo el día? ¿intraday habilitado o no?

¿Time zone acordada?

Fase 2 — STAGE Events (1–2 días)

Objetivo: aplanar eventos para que sean consultables y baratos.

Crear stage_ga4.stg_events_flat

extraer ga_session_id, page_location, utms (si están), device/geo

particionar por event_date

cluster por event_name, user_pseudo_id si aplica

QA

% eventos sin ga_session_id

volumen diario

campos críticos nulos

Fase 3 — Sessionization (1–2 días)

Objetivo: construir sesiones consistentes.

Crear stage_ga4.stg_sessions

session_id = user_pseudo_id + ga_session_id

session_start_ts, session_end_ts

events_count, pageviews

flags: has_lead, has_conversion (según event_name)

QA

session_id único

sesiones con duración negativa (no debería)

distribución de events_count

Fase 4 — OLAP (2–4 días)

Objetivo: modelo estrella mínimo pero útil.

Dimensiones:

olap.dim_date (calendario)

olap.dim_device

olap.dim_geo

olap.dim_campaign (si tenés UTMs / campos de campaña)

olap.dim_channel (reglas de canalización)

Hechos:

olap.fact_sessions (grano sesión)

olap.fact_conversions (o flags dentro de fact_sessions, según necesidad)

(Opcional) olap.fact_events (solo si el negocio requiere funnels/pathing profundo en BQ)

Decisión importante (para entrevista):

Si BI solo necesita KPIs, no hace falta fact_events en OLAP.

Si quieren análisis de journeys/funnels complejos, sí.

Fase 5 — “Marts lógicos” en Looker Studio (1–2 días)

Como vos pediste: no crear marts físicos en BigQuery.

Exponer en BigQuery views “clean” (opcionales) o tablas OLAP directas

En Looker Studio:

fuentes: fact_sessions + dims

campos calculados: sesiones, leads, conversion rate, etc.

dashboards por: Canal, Campaña, Geo, Device, Landing Page, Funnel

Fase 6 — Operación / Incremental / Costos (1–3 días)

Objetivo: que sea “productivo”.

Incremental por partición (reproceso solo últimos N días)

Auditoría:

tabla etl_run_log (fecha, status, rows, bytes, duración)

Alertas:

si no llegó data

si el volumen cae X%

Optimización:

revisar bytes procesados y queries del BI

ajustar particiones/clustering