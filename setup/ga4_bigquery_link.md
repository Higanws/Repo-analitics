# Guía: Vinculación GA4 → BigQuery

## Prerrequisitos

1. Acceso de administrador a la propiedad de GA4
2. Permisos de BigQuery Admin en el proyecto de GCP
3. El proyecto de GCP debe estar en la misma cuenta que GA4 (o tener acceso compartido)

## Pasos de Configuración

### 1. En Google Analytics 4

1. Ir a **Admin** → **BigQuery Linking**
2. Click en **Link** (si no hay links existentes)
3. Seleccionar el proyecto de GCP
4. Seleccionar la ubicación de datos (recomendado: US)
5. Configurar opciones:
   - **Daily export**: Habilitado (exporta tablas `events_YYYYMMDD`)
   - **Streaming export**: Opcional (tablas `events_intraday_YYYYMMDD`)
6. Click en **Submit**

### 2. Verificar Exportación

Después de 24-48 horas, verificar que las tablas lleguen:

```sql
-- Listar datasets
SELECT schema_name 
FROM `PROJECT_ID.INFORMATION_SCHEMA.SCHEMATA`
WHERE schema_name LIKE 'analytics_%';

-- Ver tablas de eventos (reemplazar PROPERTY_ID)
SELECT table_name, creation_time
FROM `PROJECT_ID.analytics_PROPERTY_ID.INFORMATION_SCHEMA.TABLES`
WHERE table_name LIKE 'events_%'
ORDER BY creation_time DESC
LIMIT 10;

-- Verificar estructura de una tabla
SELECT *
FROM `PROJECT_ID.analytics_PROPERTY_ID.events_20240101`
LIMIT 10;
```

### 3. Configuración de Time Zone

**Importante**: Verificar timezone en GA4:
- Admin → Property Settings → Time zone
- Asegurarse que coincida con el timezone de negocio

### 4. Habilitar Streaming (Opcional)

Si se requiere datos en tiempo real:
- En el link de BigQuery, habilitar "Streaming export"
- Esto crea tablas `events_intraday_YYYYMMDD` que se actualizan cada ~30 minutos

## Estructura de Datos RAW

Las tablas `events_YYYYMMDD` contienen:
- `event_date`: Fecha del evento (YYYYMMDD)
- `event_timestamp`: Timestamp en microsegundos
- `event_name`: Nombre del evento
- `event_params`: Array de parámetros (requiere UNNEST)
- `user_pseudo_id`: ID de usuario
- `ga_session_id`: ID de sesión
- `device`, `geo`, `traffic_source`: Objetos anidados

## Troubleshooting

### No aparecen tablas después de 48 horas

1. Verificar permisos de BigQuery
2. Verificar que el link esté activo en GA4
3. Revisar logs de BigQuery Data Transfer Service

### Datos faltantes

1. Verificar que haya tráfico en GA4
2. Verificar timezone
3. Revisar filtros en GA4 que puedan excluir datos

## Referencias

- [Documentación oficial GA4 → BigQuery](https://support.google.com/analytics/answer/9358801)
- [Estructura de datos GA4 en BigQuery](https://support.google.com/analytics/answer/7029846)
