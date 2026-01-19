"""
Operadores personalizados de BigQuery para Airflow
"""

from airflow.models import BaseOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.utils.decorators import apply_defaults


class BigQueryIncrementalMergeOperator(BaseOperator):
    """
    Operador para ejecutar MERGE incremental en BigQuery
    """
    
    template_fields = ['sql', 'target_table']
    
    @apply_defaults
    def __init__(
        self,
        sql: str,
        target_table: str,
        project_id: str = None,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.sql = sql
        self.target_table = target_table
        self.project_id = project_id
    
    def execute(self, context):
        hook = BigQueryHook(bigquery_conn_id='google_cloud_default')
        
        self.log.info(f"Ejecutando MERGE incremental en {self.target_table}")
        
        result = hook.run_query(
            sql=self.sql,
            use_legacy_sql=False,
            destination_dataset_table=self.target_table,
            write_disposition='WRITE_APPEND'
        )
        
        self.log.info(f"MERGE completado. Job ID: {result.job_id}")
        return result.job_id
