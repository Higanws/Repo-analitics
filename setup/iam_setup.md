# Configuración de IAM y Service Accounts

## Service Accounts Necesarios

### 1. Service Account para Airflow/Composer

**Nombre sugerido**: `composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com`

**Roles requeridos**:
- `roles/bigquery.dataEditor` (para escribir en stage_ga4 y olap)
- `roles/bigquery.dataViewer` (para leer de analytics_PROPERTY_ID)
- `roles/bigquery.jobUser` (para ejecutar queries)
- `roles/logging.logWriter` (para escribir logs)

**Creación**:
```bash
gcloud iam service-accounts create composer-etl-sa \
  --display-name="Composer ETL Service Account" \
  --project=PROJECT_ID

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

### 2. Service Account para Dataform (si se usa)

**Nombre sugerido**: `dataform-sa@PROJECT_ID.iam.gserviceaccount.com`

**Roles requeridos**:
- `roles/bigquery.dataEditor`
- `roles/bigquery.jobUser`

## Permisos de Usuarios

### Para Desarrolladores

**Roles recomendados**:
- `roles/bigquery.dataViewer` (lectura en todos los datasets)
- `roles/bigquery.jobUser` (ejecutar queries)
- `roles/bigquery.dataEditor` (solo en datasets de desarrollo/testing)

### Para Analistas/BI

**Roles recomendados**:
- `roles/bigquery.dataViewer` (solo lectura en olap y stage_ga4)
- `roles/bigquery.jobUser` (para queries ad-hoc)

## Row-Level Security (Opcional)

Si se requiere RLS, crear políticas en BigQuery:

```sql
-- Ejemplo: restringir acceso por región
CREATE ROW ACCESS POLICY region_filter
ON `PROJECT_ID.olap.fact_sessions`
GRANT TO ('user:analyst@company.com')
FILTER USING (region = 'US');
```

## Data Catalog Tags (Opcional)

Para gobierno de datos, etiquetar tablas:

```sql
-- Ejemplo de tags
ALTER TABLE `PROJECT_ID.olap.fact_sessions`
SET OPTIONS (
  labels=[("data_classification", "internal"), ("pii", "false")]
);
```
