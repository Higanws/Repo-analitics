"""
DAG de Data Quality
Ejecuta validaciones y assertions sobre los datos
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import BigQueryCheckOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryValueCheckOperator
from airflow.utils.dates import days_ago

PROJECT_ID = "PROJECT_ID"
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
    "data_quality_checks",
    default_args=default_args,
    description="Validaciones de calidad de datos",
    schedule_interval="0 3 * * *",  # Ejecutar después del pipeline principal
    catchup=False,
    tags=["data-quality", "validation"],
)

# =========================================================
# Assertions STAGE
# =========================================================

check_events_volume = BigQueryValueCheckOperator(
    task_id="check_events_volume",
    sql=f"""
    SELECT COUNT(*) 
    FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat`
    WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
    """,
    pass_value=100,  # Mínimo de eventos esperados
    tolerance=0.1,
    dag=dag,
)

check_sessions_volume = BigQueryValueCheckOperator(
    task_id="check_sessions_volume",
    sql=f"""
    SELECT COUNT(*) 
    FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_sessions`
    WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    """,
    pass_value=10,  # Mínimo de sesiones esperadas
    tolerance=0.1,
    dag=dag,
)

check_events_without_session = BigQueryCheckOperator(
    task_id="check_events_without_session",
    sql=f"""
    SELECT COUNT(*) = 0
    FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat`
    WHERE event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
      AND ga_session_id IS NULL
    """,
    dag=dag,
)

check_negative_session_duration = BigQueryCheckOperator(
    task_id="check_negative_session_duration",
    sql=f"""
    SELECT COUNT(*) = 0
    FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_sessions`
    WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND session_duration_seconds < 0
    """,
    dag=dag,
)

# =========================================================
# Assertions OLAP
# =========================================================

check_fact_sessions_volume = BigQueryValueCheckOperator(
    task_id="check_fact_sessions_volume",
    sql=f"""
    SELECT COUNT(*) 
    FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions`
    WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    """,
    pass_value=10,
    tolerance=0.1,
    dag=dag,
)

check_orphan_sessions = BigQueryCheckOperator(
    task_id="check_orphan_sessions",
    sql=f"""
    SELECT COUNT(*) = 0
    FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions` fs
    LEFT JOIN `{PROJECT_ID}.{OLAP_DATASET}.dim_date` dd ON fs.date_key = dd.date_key
    WHERE fs.session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND dd.date_key IS NULL
    """,
    dag=dag,
)

# Ejecutar todas las validaciones en paralelo
[check_events_volume, check_sessions_volume, check_events_without_session, 
 check_negative_session_duration] >> check_fact_sessions_volume >> check_orphan_sessions
