flowchart LR
  %% =========================================================
  %% END-TO-END (Google Analytics 4 -> BigQuery -> OLAP -> Looker Studio)
  %% Nota: Los marts/semantic model se arman en Looker (LookML)
  %% =========================================================

  subgraph GA["Google Analytics (GA4)"]
    GAUI["Google Analytics UI / Admin"]
    GAP["GA4 Property"]
    GTM["GTM / gtag.js (tracking)"]
  end

  subgraph LINK["Vinculación / Export"]
    LNK["GA4 ↔ BigQuery Link (Export)"]
  end

  subgraph BQRAW["BigQuery - RAW (Landing)"]
    RAWDS["Dataset nativo: analytics_<property_id>"]
    EV["Tables: events_YYYYMMDD<br/>events_intraday_YYYYMMDD (opcional)"]
  end

  subgraph ORCH["Orquestación / DataOps"]
    SCH["Cloud Scheduler (triggers)"]
    WF["Workflows / Composer (Airflow) (opcional)"]
    DQ["Data Quality Checks (SQL assertions)"]
    AUD["Auditoría / Control de cargas<br/>(metadata tables)"]
    LOG["Logging / Monitoring (Cloud Logging)"]
  end

  subgraph BQSTG["BigQuery - STAGE (Normalización)"]
    STGDS["Dataset: stage_ga4"]
    STGEV["stg_events_flat<br/>(UNNEST event_params + campos BI-friendly)"]
    STGSES["stg_sessions<br/>(session_id = user_pseudo_id + ga_session_id)"]
    STGUSR["stg_users (opcional)<br/>(agregados por user_pseudo_id)"]
  end

  subgraph BQOLAP["BigQuery - OLAP (Modelo Estrella)"]
    OLAPDS["Dataset: olap"]
    %% Dimensions
    DDATE["dim_date"]
    DCHAN["dim_channel"]
    DCAMP["dim_campaign"]
    DGEO["dim_geo"]
    DDEV["dim_device"]
    DEVTYPE["dim_event_type (opcional)"]
    %% Facts
    FSESS["fact_sessions<br/>(grano: sesión)"]
    FEV["fact_events (opcional)<br/>(grano: evento)"]
    FCONV["fact_conversions<br/>(leads/conversions por sesión/día)"]
  end

  subgraph SEC["Seguridad / Gobierno"]
    IAM["IAM + Service Accounts"]
    RLS["Row-Level / Column-Level Security (opcional)"]
    CATALOG["Data Catalog / Tags (opcional)"]
  end

  subgraph BI["BI / Semantic"]
    LKML["Looker (LookML / Semantic Layer)<br/>(marts lógicos)"]
    LS["Looker Studio (Dashboards)"]
  end

  %% Tracking -> GA4
  GTM --> GAP
  GAUI --> GAP

  %% GA4 -> BigQuery (export link)
  GAP --> LNK
  LNK --> RAWDS
  RAWDS --> EV

  %% Orchestration triggers transformations
  SCH --> WF
  WF --> LOG
  WF -->|"SQL jobs (CTAS/MERGE)"| STGDS
  WF -->|"SQL jobs (CTAS/MERGE)"| OLAPDS
  WF --> DQ
  WF --> AUD

  %% Raw -> Stage
  EV -->|"Flatten + extract (UNNEST event_params)"| STGEV
  STGEV -->|"Sessionization (group by user_pseudo_id + ga_session_id)"| STGSES
  STGEV -.-> STGUSR

  %% Stage -> OLAP (facts)
  STGSES --> FSESS
  STGEV --> FEV
  STGSES --> FCONV

  %% Stage -> OLAP (dims)
  STGSES --> DCAMP
  STGSES --> DCHAN
  STGEV --> DGEO
  STGEV --> DDEV
  STGEV -.-> DEVTYPE
  STGSES --> DDATE

  %% Governance connections
  IAM --- RAWDS
  IAM --- STGDS
  IAM --- OLAPDS
  RLS --- OLAPDS
  CATALOG --- OLAPDS

  %% BI consumption (semantic en Looker; dashboards en Looker Studio)
  OLAPDS -->|"BigQuery connector"| LKML
  LKML --> LS
