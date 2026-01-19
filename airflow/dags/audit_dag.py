"""
DAG de Auditoría y Monitoreo
Genera reportes y métricas de ejecución del pipeline
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import BigQueryExecuteQueryOperator
from airflow.utils.dates import days_ago

PROJECT_ID = "PROJECT_ID"
MONITORING_DATASET = "monitoring"
STAGE_DATASET = "stage_ga4"
OLAP_DATASET = "olap"

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "email_on_failure": True,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "start_date": days_ago(1),
}

dag = DAG(
    "audit_monitoring",
    default_args=default_args,
    description="Auditoría y monitoreo del pipeline ETL",
    schedule_interval="0 4 * * *",  # Ejecutar después de DQ
    catchup=False,
    tags=["audit", "monitoring"],
)

# Generar reporte de ejecuciones
generate_audit_report = BigQueryExecuteQueryOperator(
    task_id="generate_audit_report",
    sql=f"""
    CREATE OR REPLACE TABLE `{PROJECT_ID}.{MONITORING_DATASET}.daily_summary` AS
    SELECT
      DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS report_date,
      (SELECT COUNT(*) FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat` 
       WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))) AS events_count,
      (SELECT COUNT(*) FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_sessions` 
       WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS sessions_count,
      (SELECT COUNT(*) FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions` 
       WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS fact_sessions_count,
      (SELECT COUNT(*) FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_conversions` 
       WHERE conversion_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS conversions_count,
      CURRENT_TIMESTAMP() AS report_timestamp
    """,
    use_legacy_sql=False,
    dag=dag,
)
