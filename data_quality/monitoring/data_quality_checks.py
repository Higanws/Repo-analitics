"""
Scripts Python para ejecutar Data Quality checks
Puede ser usado en Airflow o ejecutado independientemente
"""

from google.cloud import bigquery
from datetime import datetime, timedelta
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ID = "PROJECT_ID"
STAGE_DATASET = "stage_ga4"
OLAP_DATASET = "olap"


def run_stage_assertions(client, check_date):
    """Ejecuta assertions de STAGE"""
    logger.info(f"Ejecutando assertions de STAGE para fecha: {check_date}")
    
    assertions = {
        "events_volume": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat`
            WHERE event_date_partition = DATE('{check_date}')
        """,
        "sessions_volume": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_sessions`
            WHERE session_date = DATE('{check_date}')
        """,
        "events_without_session": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_events_flat`
            WHERE event_date_partition = DATE('{check_date}')
              AND ga_session_id IS NULL
        """,
        "negative_session_duration": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{STAGE_DATASET}.stg_sessions`
            WHERE session_date = DATE('{check_date}')
              AND session_duration_seconds < 0
        """
    }
    
    results = {}
    for name, query in assertions.items():
        result = client.query(query).result()
        row = next(result)
        results[name] = {
            "count": row.count,
            "status": "PASS" if (name in ["events_volume", "sessions_volume"] and row.count > 0) or 
                              (name in ["events_without_session", "negative_session_duration"] and row.count == 0)
                      else "FAIL"
        }
        logger.info(f"{name}: {results[name]}")
    
    return results


def run_olap_assertions(client, check_date):
    """Ejecuta assertions de OLAP"""
    logger.info(f"Ejecutando assertions de OLAP para fecha: {check_date}")
    
    assertions = {
        "fact_sessions_volume": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions`
            WHERE session_date = DATE('{check_date}')
        """,
        "dim_date_integrity": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions` fs
            LEFT JOIN `{PROJECT_ID}.{OLAP_DATASET}.dim_date` dd ON fs.date_key = dd.date_key
            WHERE fs.session_date = DATE('{check_date}')
              AND dd.date_key IS NULL
        """,
        "dim_device_integrity": f"""
            SELECT COUNT(*) as count
            FROM `{PROJECT_ID}.{OLAP_DATASET}.fact_sessions` fs
            LEFT JOIN `{PROJECT_ID}.{OLAP_DATASET}.dim_device` dd ON fs.device_key = dd.device_key
            WHERE fs.session_date = DATE('{check_date}')
              AND dd.device_key IS NULL
        """
    }
    
    results = {}
    for name, query in assertions.items():
        result = client.query(query).result()
        row = next(result)
        results[name] = {
            "count": row.count,
            "status": "PASS" if (name == "fact_sessions_volume" and row.count > 0) or 
                              (name.endswith("_integrity") and row.count == 0)
                      else "FAIL"
        }
        logger.info(f"{name}: {results[name]}")
    
    return results


def log_dq_results(client, check_date, results, layer="stage"):
    """Registra resultados de DQ en tabla de auditoría"""
    table_id = f"{PROJECT_ID}.monitoring.data_quality_log"
    
    rows_to_insert = []
    for assertion_name, result in results.items():
        rows_to_insert.append({
            "check_date": check_date,
            "layer": layer,
            "assertion_name": assertion_name,
            "status": result["status"],
            "count": result["count"],
            "check_timestamp": datetime.utcnow().isoformat()
        })
    
    errors = client.insert_rows_json(table_id, rows_to_insert)
    if errors:
        logger.error(f"Error insertando resultados DQ: {errors}")
    else:
        logger.info(f"Resultados DQ registrados para {layer}")


def main():
    """Función principal"""
    client = bigquery.Client(project=PROJECT_ID)
    check_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    
    # Ejecutar assertions
    stage_results = run_stage_assertions(client, check_date)
    olap_results = run_olap_assertions(client, check_date)
    
    # Registrar resultados
    log_dq_results(client, check_date, stage_results, "stage")
    log_dq_results(client, check_date, olap_results, "olap")
    
    # Verificar si hay fallos
    all_failed = [k for k, v in {**stage_results, **olap_results}.items() if v["status"] == "FAIL"]
    if all_failed:
        logger.warning(f"Assertions fallidas: {all_failed}")
        return 1
    
    logger.info("Todas las assertions pasaron")
    return 0


if __name__ == "__main__":
    exit(main())
