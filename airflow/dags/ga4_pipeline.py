"""
DAG principal para pipeline GA4 → BigQuery → OLAP
Ejecuta transformaciones diarias de datos de GA4
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryExecuteQueryOperator,
    BigQueryCheckOperator
)
from airflow.providers.google.cloud.sensors.bigquery import BigQueryTableExistenceSensor
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago

# Configuración
PROJECT_ID = "PROJECT_ID"
RAW_DATASET = "analytics_PROPERTY_ID"
STAGE_DATASET = "stage_ga4"
OLAP_DATASET = "olap"
MONITORING_DATASET = "monitoring"

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "start_date": days_ago(1),
}

dag = DAG(
    "ga4_pipeline",
    default_args=default_args,
    description="Pipeline ETL diario GA4 → BigQuery → OLAP",
    schedule_interval="0 2 * * *",  # Ejecutar a las 2 AM diariamente
    catchup=False,
    tags=["ga4", "bigquery", "etl"],
)

# =========================================================
# STAGE: Aplanamiento de eventos
# =========================================================

check_raw_data = BigQueryTableExistenceSensor(
    task_id="check_raw_data",
    project_id=PROJECT_ID,
    dataset_id=RAW_DATASET.split(".")[-1] if "." in RAW_DATASET else RAW_DATASET,
    table_id="events_{{ ds_nodash }}",  # events_YYYYMMDD
    timeout=300,
    poke_interval=60,
    dag=dag,
)

stg_events_flat = BigQueryExecuteQueryOperator(
    task_id="stg_events_flat",
    sql="sql/stage/stg_events_flat.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    destination_dataset_table=f"{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat",
    dag=dag,
)

stg_sessions = BigQueryExecuteQueryOperator(
    task_id="stg_sessions",
    sql="sql/stage/stg_sessions.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    destination_dataset_table=f"{PROJECT_ID}.{STAGE_DATASET}.stg_sessions",
    dag=dag,
)

# =========================================================
# OLAP: Dimensiones
# =========================================================

dim_date = BigQueryExecuteQueryOperator(
    task_id="dim_date",
    sql="sql/olap/dimensions/dim_date.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    dag=dag,
)

dim_device = BigQueryExecuteQueryOperator(
    task_id="dim_device",
    sql="sql/olap/dimensions/dim_device.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    dag=dag,
)

dim_geo = BigQueryExecuteQueryOperator(
    task_id="dim_geo",
    sql="sql/olap/dimensions/dim_geo.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    dag=dag,
)

dim_campaign = BigQueryExecuteQueryOperator(
    task_id="dim_campaign",
    sql="sql/olap/dimensions/dim_campaign.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    dag=dag,
)

dim_channel = BigQueryExecuteQueryOperator(
    task_id="dim_channel",
    sql="sql/olap/dimensions/dim_channel.sql",
    use_legacy_sql=False,
    write_disposition="WRITE_TRUNCATE",
    dag=dag,
)

# =========================================================
# OLAP: Hechos (incremental MERGE)
# =========================================================

fact_sessions = BigQueryExecuteQueryOperator(
    task_id="fact_sessions",
    sql="sql/olap/facts/fact_sessions.sql",
    use_legacy_sql=False,
    dag=dag,
)

fact_conversions = BigQueryExecuteQueryOperator(
    task_id="fact_conversions",
    sql="sql/olap/facts/fact_conversions.sql",
    use_legacy_sql=False,
    dag=dag,
)

# =========================================================
# Data Quality Checks
# =========================================================

dq_stage_events = BigQueryCheckOperator(
    task_id="dq_stage_events",
    sql="""
    SELECT COUNT(*) 
    FROM `{{ params.project_id }}.{{ params.stage_dataset }}.stg_events_flat`
    WHERE event_date = '{{ ds_nodash }}'
    """,
    params={
        "project_id": PROJECT_ID,
        "stage_dataset": STAGE_DATASET,
    },
    dag=dag,
)

dq_stage_sessions = BigQueryCheckOperator(
    task_id="dq_stage_sessions",
    sql="""
    SELECT COUNT(*) 
    FROM `{{ params.project_id }}.{{ params.stage_dataset }}.stg_sessions`
    WHERE session_date = DATE('{{ ds }}')
    """,
    params={
        "project_id": PROJECT_ID,
        "stage_dataset": STAGE_DATASET,
    },
    dag=dag,
)

# =========================================================
# Auditoría
# =========================================================

def log_etl_run(**context):
    """Registra ejecución ETL en tabla de auditoría"""
    from google.cloud import bigquery
    
    client = bigquery.Client(project=PROJECT_ID)
    
    query = f"""
    INSERT INTO `{PROJECT_ID}.{MONITORING_DATASET}.etl_run_log`
    (run_date, dag_id, task_id, status, rows_processed, bytes_processed, duration_seconds, run_timestamp)
    VALUES
    ('{context["ds"]}', '{context["dag"].dag_id}', 'ga4_pipeline', 'success', 0, 0, 0, CURRENT_TIMESTAMP())
    """
    
    client.query(query).result()

audit_log = PythonOperator(
    task_id="audit_log",
    python_callable=log_etl_run,
    dag=dag,
)

# =========================================================
# Dependencias
# =========================================================

check_raw_data >> stg_events_flat >> stg_sessions

stg_sessions >> [dim_date, dim_device, dim_geo, dim_campaign, dim_channel]

[dim_date, dim_device, dim_geo, dim_campaign, dim_channel] >> fact_sessions >> fact_conversions

fact_conversions >> [dq_stage_events, dq_stage_sessions] >> audit_log
