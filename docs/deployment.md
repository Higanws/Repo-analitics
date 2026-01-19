# Guía de Despliegue End-to-End en GCP

Esta guía detalla todos los pasos para desplegar el pipeline completo de **GA4 → BigQuery → OLAP → Looker Studio** desde un proyecto GCP completamente nuevo (cero configuración) hasta tener dashboards funcionando.

## CLI vs Web UI - Resumen Ejecutivo

La mayoría de los pasos se pueden hacer desde **CLI (gcloud/bq)** o desde la **Web UI (Consola de GCP)**. Esta guía muestra ambas opciones cuando es posible.

### Se puede hacer desde CLI (gcloud/bq)

- Crear proyecto GCP
- Habilitar APIs
- Configurar BigQuery (datasets, tablas)
- Configurar IAM y Service Accounts
- Desplegar Cloud Composer
- Ejecutar scripts SQL
- Monitorear con logs

**Ventaja CLI**: Más rápido, automatizable, versionable con scripts.

### Solo desde Web UI (Obligatorio)

- **Activar facturación** (primera vez - requiere tarjeta)
- **Link GA4 → BigQuery** (no hay API pública)
- **Looker Studio** (solo desde datastudio.google.com)

### Recomendación

- **Desarrollo/Automatización**: Usar CLI cuando sea posible
- **Configuración inicial**: Web UI es más intuitiva para la primera vez
- **Operaciones diarias**: CLI para scripts, Web UI para exploración

Cada paso en esta guía indica si se puede hacer desde CLI, Web UI, o ambos.

## Indice de Pasos

1. **Paso 0**: Crear proyecto GCP desde cero
2. **Paso 1**: Instalar herramientas y configurar proyecto
3. **Paso 2**: Habilitar APIs necesarias
4. **Paso 3**: Configurar BigQuery (datasets, IAM)
5. **Paso 4**: Configurar link GA4 → BigQuery
6. **Paso 5**: Crear tabla de auditoría
7. **Paso 6**: Desplegar Cloud Composer (Airflow)
8. **Paso 7**: Crear tablas base (dimensiones y hechos)
9. **Paso 8**: Verificar y ejecutar pipeline
10. **Paso 9**: Configurar Dataform (opcional)
11. **Paso 10**: Configurar Looker Studio (completo)
12. **Paso 11**: Monitoreo y alertas
13. **Paso 12**: Optimización y mantenimiento

## Paso 0: Crear Proyecto GCP desde Cero

> **Nota**: Paso 0.1 y 0.2 requieren **Web UI**. Paso 0.2 también puede hacerse desde CLI.

### 0.1 Crear Cuenta de Google Cloud (Web UI - Obligatorio)

**Solo desde Web UI**

1. Ir a [Google Cloud Console](https://console.cloud.google.com/)
2. Iniciar sesión con tu cuenta de Google
3. Si es la primera vez, aceptar términos y condiciones
4. **Activar facturación** (requerido para usar BigQuery y Composer)
   - Click en el menú ☰ → Facturación
   - Agregar método de pago (tarjeta de crédito)
   - **Nota**: Google Cloud ofrece créditos gratuitos ($300 USD por 90 días)

### 0.2 Crear Nuevo Proyecto

**Opción A: Desde Web UI** (Recomendado para primera vez)

1. En la consola de GCP, click en el selector de proyectos (arriba a la izquierda)
2. Click en **"Nuevo Proyecto"**
3. Configurar proyecto:
   - **Nombre del proyecto**: `ga4-analytics-prod` (o el que prefieras)
   - **Organización**: (opcional) si perteneces a una organización
   - **Ubicación**: (opcional)
4. Click en **"Crear"**
5. **Anotar el PROJECT_ID** generado (ejemplo: `ga4-analytics-prod-123456`)
   - El PROJECT_ID aparece en el selector de proyectos

**Opción B: Desde CLI**

```bash
# Crear proyecto
gcloud projects create PROJECT_ID --name="GA4 Analytics Pipeline"

# O con más opciones
gcloud projects create PROJECT_ID \
  --name="GA4 Analytics Pipeline" \
  --organization=ORGANIZATION_ID  # opcional

# Listar proyectos para verificar
gcloud projects list

# Anotar el PROJECT_ID que aparece en la columna PROJECT_ID
```

**Nota**: El PROJECT_ID debe ser único globalmente. Si está ocupado, prueba con otro nombre.

### 0.3 Verificar Facturación Activa

**Opción A: Desde Web UI**

1. Ir a ☰ → Facturación
2. Verificar que tu proyecto está vinculado a una cuenta de facturación

**Opción B: Desde CLI**

```bash
# Ver proyectos y su estado de facturación
gcloud beta billing projects list

# Verificar facturación específica
gcloud beta billing projects describe PROJECT_ID
```

### 0.4 Instalar Google Cloud SDK (gcloud CLI)

**En Windows:**

1. Descargar desde [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
2. Ejecutar el instalador
3. Seguir el asistente de instalación
4. Abrir PowerShell o CMD y verificar:

```powershell
gcloud --version
```

**En Linux/Mac:**

```bash
# Instalar gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Verificar instalación
gcloud --version
```

### 0.5 Instalar BigQuery CLI (bq)

`bq` viene incluido con Google Cloud SDK. Verificar:

```bash
bq version
```

Si no está instalado:

```bash
# En Windows (PowerShell como administrador)
gcloud components install bq

# En Linux/Mac
gcloud components install bq
```

### 0.6 Inicializar gcloud

```bash
# Iniciar sesión
gcloud auth login

# Se abrirá el navegador para autenticarse
# Seleccionar tu cuenta de Google

# Configurar proyecto por defecto
gcloud config set project PROJECT_ID
# Reemplazar PROJECT_ID con tu proyecto ID

# Verificar configuración
gcloud config list
```

**Salida esperada:**
```
[core]
account = tu-email@gmail.com
project = PROJECT_ID
```

## Paso 1: Configuración Inicial del Proyecto

### 1.1 Configurar Variables del Proyecto

Editar los siguientes archivos y reemplazar placeholders:

```bash
# Reemplazar en todos los archivos SQL
PROJECT_ID → tu-project-id
PROPERTY_ID → tu-ga4-property-id
```

**Archivos a actualizar:**
- `setup/datasets.sql`
- `sql/stage/*.sql`
- `sql/olap/**/*.sql`
- `airflow/dags/*.py`
- `airflow/config/config.yaml`
- `dataform/dataform.json`

### 1.2 Autenticación en GCP

```bash
# Login en GCP
gcloud auth login

# Configurar proyecto por defecto
gcloud config set project PROJECT_ID

# Verificar configuración
gcloud config list
```

## Paso 2: Habilitar APIs Necesarias

> **Se puede hacer desde CLI o Web UI** - CLI es más rápido.

### Opción A: Desde CLI (Recomendado)

```bash
# BigQuery API
gcloud services enable bigquery.googleapis.com --project=PROJECT_ID

# Cloud Composer API (para Airflow)
gcloud services enable composer.googleapis.com --project=PROJECT_ID

# Cloud Storage API (requerido por Composer)
gcloud services enable storage-component.googleapis.com --project=PROJECT_ID

# Cloud Logging API
gcloud services enable logging.googleapis.com --project=PROJECT_ID

# Cloud Monitoring API
gcloud services enable monitoring.googleapis.com --project=PROJECT_ID

# Dataform API (si se usa)
gcloud services enable dataform.googleapis.com --project=PROJECT_ID

# Verificar APIs habilitadas
gcloud services list --enabled --project=PROJECT_ID
```

### Opción B: Desde Web UI

1. Ir a ☰ → **APIs y servicios** → **Biblioteca**
2. Buscar cada API y hacer click en **"Habilitar"**:
   - `BigQuery API`
   - `Cloud Composer API`
   - `Cloud Storage API`
   - `Cloud Logging API`
   - `Cloud Monitoring API`
   - `Dataform API` (si se usa)
3. Verificar en ☰ → **APIs y servicios** → **APIs habilitadas**

## Paso 3: Configurar BigQuery

> **Se puede hacer desde CLI (bq) o Web UI** - CLI es más rápido para scripts.

### 3.1 Crear Datasets

**Opción A: Desde CLI (Recomendado para automatización)**

```bash
# Ejecutar script de creación de datasets
bq query --use_legacy_sql=false < setup/datasets.sql
```

O manualmente desde CLI:

```bash
# Dataset STAGE
bq mk --dataset --location=US PROJECT_ID:stage_ga4

# Dataset OLAP
bq mk --dataset --location=US PROJECT_ID:olap

# Dataset MONITORING
bq mk --dataset --location=US PROJECT_ID:monitoring

# Verificar datasets creados
bq ls --datasets
```

**Opción B: Desde Web UI (BigQuery Console)**

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. En el panel izquierdo, hacer click en tu PROJECT_ID
3. Click en **"Crear conjunto de datos"** (Create dataset)
4. Configurar:
   - **ID del conjunto de datos**: `stage_ga4`
   - **Ubicación de datos**: `US (multiple regions)`
5. Click en **"Crear conjunto de datos"**
6. Repetir para `olap` y `monitoring`

**Verificar datasets:**
- **CLI**: `bq ls --datasets`
- **Web UI**: Panel izquierdo en BigQuery Console

### 3.2 Configurar IAM y Service Accounts

Seguir la guía en `setup/iam_setup.md`:

```bash
# Crear service account para Composer
gcloud iam service-accounts create composer-etl-sa \
  --display-name="Composer ETL Service Account" \
  --project=PROJECT_ID

# Asignar roles
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

## Paso 4: Configurar link GA4 → BigQuery

> **Solo desde Web UI** - No hay API pública para configurar este link.

### Pasos (Web UI - Obligatorio)

Seguir la guía detallada en `setup/ga4_bigquery_link.md`:

1. **Ir a Google Analytics 4**
   - Abrir [Google Analytics](https://analytics.google.com/)
   - Seleccionar tu propiedad GA4

2. **Configurar link**
   - Ir a **Admin** → **BigQuery Linking**
   - Click en **"Link"** (si no hay links existentes)

3. **Seleccionar proyecto**
   - Seleccionar tu proyecto de GCP (`PROJECT_ID`)
   - Click en **"Confirmar"**

4. **Configurar exportación**
   - **Ubicación de datos**: `US (multiple regions)` (recomendado)
   - **Daily export**: Habilitado (exporta tablas `events_YYYYMMDD`)
   - **Streaming export**: Opcional (tablas `events_intraday_YYYYMMDD`)

5. **Finalizar**
   - Click en **"Submit"**
   - Esperar confirmación del link

### Verificar Exportación

**Opción A: Desde CLI** (después de 24-48 horas)

```bash
# Listar datasets de GA4 (esperar 24-48 horas)
bq ls

# Ver tablas de eventos
bq ls analytics_PROPERTY_ID

# Ver estructura de una tabla de eventos
bq show analytics_PROPERTY_ID.events_YYYYMMDD
```

**Opción B: Desde Web UI (BigQuery Console)**

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. En el panel izquierdo, buscar dataset `analytics_PROPERTY_ID`
3. Click para expandir y ver tablas `events_YYYYMMDD`
4. Click en una tabla para ver su estructura

**Nota**: Las tablas pueden tardar 24-48 horas en aparecer después de configurar el link.

## Paso 5: Crear Tabla de Auditoría

> **Se puede hacer desde CLI (bq) o Web UI (BigQuery Console)**.

### Opción A: Desde CLI

```bash
# Crear tabla desde archivo SQL
bq query --use_legacy_sql=false < monitoring/etl_run_log.sql

# O ejecutar directamente
bq query --use_legacy_sql=false "
CREATE TABLE \`PROJECT_ID.monitoring.etl_run_log\`
(
  run_id STRING,
  run_date DATE,
  dag_id STRING,
  task_id STRING,
  status STRING,
  rows_processed INT64,
  bytes_processed INT64,
  duration_seconds INT64,
  error_message STRING,
  run_timestamp TIMESTAMP
)
PARTITION BY run_date
CLUSTER BY dag_id, status;
"
```

### Opción B: Desde Web UI (BigQuery Console)

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Seleccionar dataset `monitoring`
3. Click en **"Crear tabla"** (Create table)
4. **Fuente**: Seleccionar **"Tabla vacía"** (Empty table)
5. **Detalles**:
   - **Nombre de la tabla**: `etl_run_log`
   - **Esquema**: Click en **"Editar como texto"** y pegar:
   ```
   run_id:STRING,run_date:DATE,dag_id:STRING,task_id:STRING,status:STRING,rows_processed:INT64,bytes_processed:INT64,duration_seconds:INT64,error_message:STRING,run_timestamp:TIMESTAMP
   ```
6. **Particionado**: 
   - Click en **"Particionar por campo"**
   - Seleccionar `run_date`
7. **Clustering**:
   - Campos de agrupación en clúster: `dag_id`, `status`
8. Click en **"Crear tabla"**

## Paso 6: Desplegar Cloud Composer (Airflow)

> **Se puede hacer desde CLI o Web UI** - CLI es más rápido para automatización.

### 6.1 Crear Entorno de Composer

**Opción A: Desde CLI (Recomendado)**

```bash
# Crear entorno de Composer (puede tardar 20-30 minutos)
gcloud composer environments create ga4-composer \
  --location=us-central1 \
  --node-count=3 \
  --machine-type=n1-standard-1 \
  --disk-size=30GB \
  --python-version=3 \
  --image-version=composer-2.7.0-airflow-2.7.0 \
  --service-account=composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com
```

**Opción B: Desde Web UI**

1. Ir a ☰ → **Cloud Composer** → **Crear entorno**
2. Configurar:
   - **Nombre**: `ga4-composer`
   - **Ubicación**: `us-central1`
   - **Tipo de entorno**: `Composer 2`
   - **Image version**: `composer-2.7.0-airflow-2.7.0`
   - **Service account**: `composer-etl-sa@PROJECT_ID.iam.gserviceaccount.com`
3. Click en **"Crear"** y esperar 20-30 minutos

### 6.2 Obtener Información del Entorno

```bash
# Obtener bucket de DAGs
gcloud composer environments describe ga4-composer \
  --location=us-central1 \
  --format="value(config.dagGcsPrefix)"

# Output: gs://us-central1-ga4-composer-xxxxx-bucket/dags
```

### 6.3 Subir DAGs

```bash
# Configurar variables
COMPOSER_BUCKET=$(gcloud composer environments describe ga4-composer \
  --location=us-central1 \
  --format="value(config.dagGcsPrefix)")

# Subir DAGs
gsutil -m cp -r airflow/dags/* $COMPOSER_BUCKET/

# Subir plugins (si existen)
gsutil -m cp -r airflow/plugins/* $COMPOSER_BUCKET/plugins/

# Subir configuración
gsutil cp airflow/config/config.yaml $COMPOSER_BUCKET/config/
```

### 6.4 Instalar Dependencias Python

```bash
# Crear archivo requirements.txt en el bucket
gsutil cp requirements.txt $COMPOSER_BUCKET/

# O instalar en el entorno de Composer
gcloud composer environments update ga4-composer \
  --location=us-central1 \
  --update-pypi-packages-from-file=requirements.txt
```

### 6.5 Configurar Variables de Airflow

```bash
# Obtener nombre del entorno
ENV_NAME=ga4-composer
LOCATION=us-central1

# Configurar variables
gcloud composer environments run $ENV_NAME \
  --location=$LOCATION \
  variables -- \
  set PROJECT_ID PROJECT_ID

gcloud composer environments run $ENV_NAME \
  --location=$LOCATION \
  variables -- \
  set RAW_DATASET analytics_PROPERTY_ID

gcloud composer environments run $ENV_NAME \
  --location=$LOCATION \
  variables -- \
  set STAGE_DATASET stage_ga4

gcloud composer environments run $ENV_NAME \
  --location=$LOCATION \
  variables -- \
  set OLAP_DATASET olap
```

## Paso 7: Crear Tablas Base (Primera Ejecución)

> **Se puede hacer desde CLI (bq) o Web UI (BigQuery Console)** - CLI recomendado para scripts.

### 7.1 Ejecutar Scripts de Dimensiones (Una vez)

**Opción A: Desde CLI (Recomendado)**

```bash
# Dimensiones (ejecutar una vez, no son incrementales)
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_date.sql
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_device.sql
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_geo.sql
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_campaign.sql
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_channel.sql
bq query --use_legacy_sql=false < sql/olap/dimensions/dim_event_type.sql
```

**Opción B: Desde Web UI (BigQuery Console)**

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Seleccionar dataset `olap`
3. Click en **"Crear consulta"** (Create query)
4. Copiar y pegar el contenido de cada script SQL:
   - `sql/olap/dimensions/dim_date.sql`
   - `sql/olap/dimensions/dim_device.sql`
   - etc.
5. Click en **"Ejecutar"** para cada script

### 7.2 Crear Tablas de Hechos (Estructura)

**Opción A: Desde CLI (Recomendado)**

```bash
# Crear estructura de fact_sessions (el MERGE se ejecutará en el DAG)
bq query --use_legacy_sql=false < sql/olap/facts/fact_sessions.sql

# Crear estructura de fact_conversions
bq query --use_legacy_sql=false < sql/olap/facts/fact_conversions.sql

# (Opcional) Crear fact_events
bq query --use_legacy_sql=false < sql/olap/facts/fact_events.sql
```

**Opción B: Desde Web UI (BigQuery Console)**

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Seleccionar dataset `olap`
3. Para cada script en `sql/olap/facts/`:
   - Click en **"Crear consulta"**
   - Copiar y pegar el contenido del script SQL
   - Click en **"Ejecutar"**

## Paso 8: Verificar y Ejecutar Pipeline

> **Monitoreo: CLI o Web UI** - Ejecución: CLI o Web UI.

### 8.1 Verificar DAGs en Airflow UI

**Opción A: Desde CLI - Obtener URL**

```bash
# Obtener URL de Airflow
gcloud composer environments describe ga4-composer \
  --location=us-central1 \
  --format="value(config.airflowUri)"
```

**Opción B: Acceder a Web UI**

1. Copiar la URL del comando anterior o ir a ☰ → **Cloud Composer**
2. Click en el entorno `ga4-composer`
3. Click en **"Abrir interfaz web de Airflow"**
4. Login con cuenta de GCP
5. Verificar que los DAGs aparezcan:
   - `ga4_pipeline`
   - `data_quality_checks`
   - `audit_monitoring`

### 8.2 Ejecutar Primera Carga Manual

**Opción A: Desde CLI**

```bash
# Trigger manual del DAG desde CLI
gcloud composer environments run ga4-composer \
  --location=us-central1 \
  dags trigger -- ga4_pipeline

# Verificar estado
gcloud composer environments run ga4-composer \
  --location=us-central1 \
  dags list-runs -- ga4_pipeline --state running
```

**Opción B: Desde Web UI (Airflow UI)**

1. Ir a la URL de Airflow (Paso 8.1)
2. Buscar DAG `ga4_pipeline`
3. Activar el DAG (toggle ON/OFF)
4. Click en el DAG → **"Trigger DAG"** (ícono play)

### 8.3 Monitorear Ejecución

```bash
# Ver logs del DAG
gcloud composer environments run ga4-composer \
  --location=us-central1 \
  dags list-runs -- ga4_pipeline --state running

# Ver logs de una tarea específica
gcloud logging read "resource.type=cloud_composer_environment AND \
  resource.labels.environment_name=ga4-composer AND \
  jsonPayload.dag_id=ga4_pipeline" \
  --limit=50
```

## Paso 9: Configurar Dataform (Opcional)

Si se prefiere usar Dataform en lugar de ejecutar SQL directamente:

### 9.1 Instalar Dataform CLI

```bash
npm install -g @dataform/cli
```

### 9.2 Configurar Dataform

```bash
cd dataform
# Editar dataform.json con PROJECT_ID

# Compilar
dataform compile

# Ejecutar
dataform run
```

## Paso 10: Configurar Looker Studio (End-to-End)

> **Solo desde Web UI** - Looker Studio solo está disponible desde la interfaz web (datastudio.google.com).

### 10.1 Verificar Datos en BigQuery

Antes de conectar Looker Studio, verificar que haya datos:

```sql
-- Ejecutar en BigQuery Console
SELECT COUNT(*) as total_sessions
FROM `PROJECT_ID.olap.mart_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
```

### 10.2 Crear Conexión a BigQuery

1. **Ir a Looker Studio**
   - Abrir [https://datastudio.google.com](https://datastudio.google.com)
   - Iniciar sesión con la misma cuenta de Google que GCP

2. **Crear Nueva Fuente de Datos**
   - Click en **"Crear"** → **"Fuente de datos"**
   - En el panel izquierdo, buscar **"BigQuery"**
   - Click en **"BigQuery"**

3. **Seleccionar Proyecto y Tabla**
   - **Seleccionar proyecto**: Buscar tu `PROJECT_ID` en la lista
   - **Seleccionar dataset**: `olap`
   - **Seleccionar tabla**: 
     - `mart_sessions` (para análisis de sesiones)
     - O `mart_conversions` (para análisis de conversiones)

4. **Configurar Conexión**
   - Click en **"Conectar"** (arriba a la derecha)
   - Se abrirá el editor de campos

### 10.3 Configurar Campos en Looker Studio

En el editor de campos, puedes:

**Campos calculados útiles:**

1. **Conversion Rate**:
   ```
   SAFE_DIVIDE(conversions, sessions) * 100
   ```

2. **Sesiones Engaged Rate**:
   ```
   SAFE_DIVIDE(engaged_sessions, sessions) * 100
   ```

3. **Avg Session Duration (minutes)**:
   ```
   session_duration_seconds / 60
   ```

**Agregar métricas:**
- Click en **"+ Agregar un campo"** para crear campos calculados
- Nombre el campo (ej: `Conversion Rate`)
- Fórmula: `SAFE_DIVIDE(conversions, sessions) * 100`
- Tipo: Número
- Click en **"Guardar"**

### 10.4 Crear Reporte/Dashboard

1. **Crear Reporte**
   - Click en **"Crear informe"** (arriba a la derecha)
   - Si aparece popup "Agregar fuente de datos al informe", click en **"Agregar a informe"**

2. **Agregar Gráficos Básicos**

   **Tabla por Canal:**
   - Click en **"Agregar un gráfico"** → **"Tabla"**
   - Dimensiones: `channel_group`, `channel_type`
   - Métricas: `sessions`, `conversions`, `Conversion Rate`
   - Click para aplicar

   **Gráfico de líneas temporal:**
   - Click en **"Agregar un gráfico"** → **"Gráfico de líneas temporales"**
   - Dimensión: `session_date` (o `month` para mensual)
   - Métricas: `sessions`, `conversions`
   - Click para aplicar

   **Gráfico de barras por Canal:**
   - Click en **"Agregar un gráfico"** → **"Gráfico de barras"**
   - Dimensión: `channel_group`
   - Métrica: `sessions`
   - Click para aplicar

   **Tarjetas de resumen (KPIs):**
   - Click en **"Agregar un gráfico"** → **"Puntuación"**
   - Métrica: `sessions` (o `conversions`, `Conversion Rate`)
   - Título: "Total Sesiones" (o el KPI que sea)

### 10.5 Dashboard Completo - Ejemplo de Estructura

**Panel Superior (KPIs):**
```
[Sesiones Totales] [Conversiones] [Conversion Rate] [Avg Session Duration]
```

**Panel Medio:**
```
[Sesiones por Fecha - Línea]    [Sesiones por Canal - Barras]
```

**Panel Inferior:**
```
[Tabla detallada: Canal, Campaña, Geo, Sessions, Conversions]
```

### 10.6 Filtrar y Segmentar Datos

**Agregar Filtros:**

1. Click en el menú (⋮) del gráfico → **"Aplicar filtro"**
2. Seleccionar campo (ej: `channel_group`, `country`, `device_category`)
3. Seleccionar condición (es igual a, contiene, etc.)
4. Agregar valores

**Control de filtro (para todo el dashboard):**

1. Click en **"Agregar un control"** → **"Control de filtro"**
2. Seleccionar campo (ej: `channel_group`)
3. Esto creará un dropdown que filtra todos los gráficos

### 10.7 Compartir Dashboard

1. Click en **"Compartir"** (arriba a la derecha)
2. **Opciones:**
   - **"Obtener link compartible"**: Para compartir con cualquier persona
   - **"Invitar personas"**: Para acceso específico
   - **Permisos**:
     - **"Pueden ver"**: Solo lectura
     - **"Pueden editar"**: Pueden modificar el dashboard

### 10.8 Actualización de Datos

- **Automático**: Los datos se actualizan automáticamente desde BigQuery
- **Frecuencia**: Según el horario del DAG de Airflow (por defecto 2 AM diariamente)
- **Forzar actualización**: En Looker Studio, menú → **"Gestionar fuentes de datos"** → Click en tu fuente → **"Actualizar ahora"**

### 10.9 Referencia Rápida - Campos Disponibles en mart_sessions

**Dimensiones:**
- `session_date`, `year`, `quarter`, `month`, `week`, `day_name`
- `channel_group`, `channel_type`, `source`, `medium`
- `utm_source`, `utm_medium`, `utm_campaign`
- `device_category`, `device_type_group`, `operating_system`
- `country`, `region`, `city`, `region_group`
- `landing_page`, `exit_page`

**Métricas:**
- `sessions` (COUNT de sesiones)
- `conversions` (COUNT de conversiones)
- `leads` (COUNT de leads)
- `engaged_sessions`
- `pageviews`
- `session_duration_seconds`
- `total_conversion_value`
- `total_purchase_revenue`

### 10.10 Ejemplo de Dashboard - Queries Útiles

Para validar datos antes de crear dashboards:

```sql
-- Sesiones por canal (últimos 30 días)
SELECT 
  channel_group,
  COUNT(*) as sessions,
  SUM(conversions) as conversions,
  ROUND(SUM(conversions) / COUNT(*) * 100, 2) as conversion_rate
FROM `PROJECT_ID.olap.mart_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY channel_group
ORDER BY sessions DESC;

-- Sesiones por fecha
SELECT 
  session_date,
  COUNT(*) as sessions,
  SUM(conversions) as conversions
FROM `PROJECT_ID.olap.mart_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY session_date
ORDER BY session_date DESC;
```

### 10.11 Checklist Looker Studio

- [ ] Fuente de datos conectada a BigQuery
- [ ] Campos calculados creados (conversion rate, etc.)
- [ ] Dashboard con KPIs principales
- [ ] Gráficos temporales (líneas)
- [ ] Gráficos por canal/geo/device (barras)
- [ ] Tabla detallada con métricas
- [ ] Filtros configurados
- [ ] Dashboard compartido con usuarios
- [ ] Datos actualizándose automáticamente

## Paso 11: Monitoreo y Alertas

### 11.1 Configurar Alertas de Cloud Monitoring

```bash
# Crear política de alerta para fallos del DAG
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="GA4 Pipeline Failure" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s \
  --condition-filter='resource.type="cloud_composer_environment" AND \
    metric.type="composer.googleapis.com/environment/dag_run_failed"'
```

### 11.2 Configurar Alertas de BigQuery

Crear alertas para:
- Falta de datos diarios
- Caída de volumen > 20%
- Errores en Data Quality checks

## Paso 12: Optimización y Mantenimiento

### 12.1 Verificar Particionado y Clustering

```bash
# Ejecutar script de optimización
bq query --use_legacy_sql=false < sql/optimization/optimize_tables.sql
```

### 12.2 Monitorear Costos

```bash
# Ver uso de BigQuery
bq query --use_legacy_sql=false "
SELECT
  job_id,
  creation_time,
  total_bytes_processed,
  total_bytes_billed,
  total_slot_ms
FROM \`PROJECT_ID.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT\`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY total_bytes_billed DESC
LIMIT 10;
"
```

### 12.3 Limpieza de Datos Antiguos

Configurar política de retención (ejemplo: 2 años):

```sql
-- Ejecutar periódicamente (ej: mensualmente)
DELETE FROM `PROJECT_ID.stage_ga4.stg_events_flat`
WHERE event_date_partition < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

DELETE FROM `PROJECT_ID.stage_ga4.stg_sessions`
WHERE session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

DELETE FROM `PROJECT_ID.olap.fact_sessions`
WHERE session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);
```

## Troubleshooting

### Problema: DAG no aparece en Airflow

**Solución:**
- Verificar que los archivos estén en el bucket correcto
- Revisar logs de Composer: `gcloud logging read "resource.type=cloud_composer_environment"`
- Verificar sintaxis Python de los DAGs

### Problema: Error de permisos en BigQuery

**Solución:**
- Verificar que el service account tenga los roles correctos
- Verificar IAM en el proyecto
- Revisar `setup/iam_setup.md`

### Problema: No llegan datos de GA4

**Solución:**
- Verificar que el link GA4 → BigQuery esté activo
- Esperar 24-48 horas después de crear el link
- Verificar que haya tráfico en GA4
- Revisar `setup/ga4_bigquery_link.md`

### Problema: Queries muy lentas

**Solución:**
- Verificar que las tablas tengan particionado y clustering
- Ejecutar `sql/optimization/optimize_tables.sql`
- Revisar queries y agregar filtros por partición

## Resumen: CLI vs Web UI por Paso

Esta tabla indica qué opción usar para cada paso del despliegue:

| Paso | Tarea | CLI | Web UI | Notas |
|------|-------|-----|--------|-------|
| 0.1 | Crear cuenta GCP | No | Si | Solo web UI |
| 0.2 | Crear proyecto | Si | Si | CLI: `gcloud projects create` |
| 0.3 | Activar facturación | Parcial | Si | Primera vez: web UI obligatorio |
| 1 | Configurar variables | Si | N/A | Editar archivos localmente |
| 2 | Habilitar APIs | Si | Si | CLI más rápido: `gcloud services enable` |
| 3.1 | Crear datasets BigQuery | Si | Si | CLI: `bq mk --dataset` |
| 3.2 | Configurar IAM | Si | Si | CLI recomendado para scripts |
| 4 | Link GA4→BigQuery | No | Si | **Solo web UI** (no hay API) |
| 5 | Tabla auditoría | Si | Si | CLI: `bq query` o BigQuery Console |
| 6 | Cloud Composer | Si | Si | CLI: `gcloud composer environments create` |
| 7 | Crear tablas SQL | Si | Si | CLI: `bq query` o BigQuery Console |
| 8.1 | Verificar DAGs | Si | Si | CLI para URL, web UI para ver |
| 8.2 | Ejecutar DAG | Si | Si | CLI: `gcloud composer dags trigger` |
| 8.3 | Monitorear | Si | Si | CLI: `gcloud logging`, web UI para visual |
| 9 | Dataform | Si | N/A | CLI: `dataform compile/run` |
| 10 | Looker Studio | No | Si | **Solo web UI** (datastudio.google.com) |
| 11 | Alertas/Monitoreo | Si | Si | CLI: `gcloud monitoring`, web UI para config |
| 12 | Optimización | Si | Si | CLI: `bq query` o BigQuery Console |

**Leyenda:**
- Si = Se puede hacer desde esa opción
- No = No disponible desde esa opción
- Parcial = Parcialmente (requiere web UI la primera vez)
- N/A = No aplica

**Recomendación general:**
- **Desarrollo/Automatización**: Usar CLI cuando sea posible
- **Primera vez/Exploración**: Web UI puede ser más intuitiva
- **Scripts/CI-CD**: CLI es ideal

## Checklist de Despliegue

- [ ] APIs habilitadas en GCP
- [ ] Datasets creados en BigQuery
- [ ] Service accounts configurados con roles correctos
- [ ] Link GA4 → BigQuery configurado y activo
- [ ] Tabla de auditoría creada
- [ ] Cloud Composer creado y configurado
- [ ] DAGs subidos al bucket de Composer
- [ ] Variables de Airflow configuradas
- [ ] Dimensiones creadas (una vez)
- [ ] Tablas de hechos creadas (estructura)
- [ ] DAGs ejecutándose correctamente
- [ ] Data Quality checks pasando
- [ ] Looker Studio conectado a BigQuery
- [ ] Dashboards creados
- [ ] Alertas configuradas
- [ ] Documentación actualizada

## Referencias

- [Documentación BigQuery](https://cloud.google.com/bigquery/docs)
- [Documentación Cloud Composer](https://cloud.google.com/composer/docs)
- [Documentación Dataform](https://cloud.google.com/dataform/docs)
- [Guía de GA4 en BigQuery](https://support.google.com/analytics/answer/9358801)
