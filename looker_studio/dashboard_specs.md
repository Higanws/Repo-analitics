# Especificaciones de Dashboards - Looker Studio

Este documento especifica los dashboards recomendados para el proyecto de analytics GA4.

## Dashboard Principal: Overview General

### KPIs Superiores (Tarjetas de Puntuación)

| KPI | Métrica | Fórmula |
|-----|---------|---------|
| Total Sesiones | `sessions` | COUNT de sesiones |
| Total Conversiones | `conversions` | SUM de conversions |
| Conversion Rate | `Conversion Rate %` | `SAFE_DIVIDE(conversions, sessions) * 100` |
| Avg Session Duration | `Avg Duration (min)` | `AVG(session_duration_seconds) / 60` |
| Total Leads | `leads` | SUM de leads |
| Engaged Sessions | `engaged_sessions` | SUM de engaged_sessions |

### Gráficos Principales

1. **Sesiones por Fecha (Gráfico de Líneas)**
   - Dimensión: `session_date`
   - Métricas: `sessions`, `conversions`
   - Período: Últimos 30 días

2. **Sesiones por Canal (Gráfico de Barras)**
   - Dimensión: `channel_group`
   - Métrica: `sessions`
   - Ordenar por: `sessions` DESC

3. **Conversion Rate por Canal (Gráfico de Barras)**
   - Dimensión: `channel_group`
   - Métrica: `Conversion Rate %`

4. **Sesiones por Dispositivo (Gráfico de Torta)**
   - Dimensión: `device_category`
   - Métrica: `sessions`

5. **Top Países (Tabla)**
   - Dimensión: `country`
   - Métricas: `sessions`, `conversions`, `Conversion Rate %`
   - Filtrar: Top 10

## Dashboard: Análisis por Canal

### KPIs

- Sesiones por Canal
- Conversion Rate por Canal
- Costo por Lead (si hay datos de costos)

### Gráficos

1. **Sesiones por Canal y Fecha (Heatmap/Tabla)**
   - Dimensiones: `channel_group`, `session_date`
   - Métricas: `sessions`, `conversions`

2. **Comparación de Canales (Gráfico de Barras Agrupadas)**
   - Dimensión: `channel_group`
   - Métricas: `sessions`, `conversions`, `leads`

3. **Funnel de Conversión por Canal (Gráfico de Embudo)**
   - Paso 1: `sessions`
   - Paso 2: `engaged_sessions`
   - Paso 3: `conversions`

## Dashboard: Análisis por Campaña

### KPIs

- Total Campañas Activas
- Mejor Campaña (por conversiones)
- ROI Promedio (si hay costos)

### Gráficos

1. **Rendimiento por Campaña (Tabla)**
   - Dimensiones: `utm_campaign`, `utm_source`, `utm_medium`
   - Métricas: `sessions`, `conversions`, `Conversion Rate %`, `total_conversion_value`

2. **Top Landing Pages (Tabla)**
   - Dimensión: `landing_page`
   - Métricas: `sessions`, `conversions`
   - Filtrar: Top 20

## Dashboard: Análisis Geográfico

### KPIs

- Total Países
- Top País (por sesiones)

### Gráficos

1. **Sesiones por País (Mapa)**
   - Dimensión: `country`
   - Métrica: `sessions`

2. **Sesiones por Región (Tabla)**
   - Dimensiones: `country`, `region`
   - Métricas: `sessions`, `conversions`

3. **Sesiones por Ciudad (Tabla)**
   - Dimensión: `city`
   - Métricas: `sessions`, `conversions`
   - Filtrar: Top 20

## Dashboard: Análisis de Dispositivos

### KPIs

- Sesiones Mobile vs Desktop
- Conversion Rate por Tipo de Dispositivo

### Gráficos

1. **Sesiones por Dispositivo (Torta)**
   - Dimensión: `device_category`
   - Métrica: `sessions`

2. **Conversion Rate por OS (Barras)**
   - Dimensión: `operating_system`
   - Métrica: `Conversion Rate %`

## Campos Calculados Recomendados

### Conversion Rate
```
SAFE_DIVIDE(conversions, sessions) * 100
```

### Lead Rate
```
SAFE_DIVIDE(leads, sessions) * 100
```

### Avg Session Duration (minutes)
```
AVG(session_duration_seconds) / 60
```

### Engaged Session Rate
```
SAFE_DIVIDE(engaged_sessions, sessions) * 100
```

### Revenue per Session
```
SAFE_DIVIDE(total_conversion_value, sessions)
```

### Bounce Rate (si tienes datos)
```
100 - SAFE_DIVIDE(engaged_sessions, sessions) * 100
```

## Filtros Globales Recomendados

Agregar controles de filtro para:

1. **Rango de Fechas**
   - Campo: `session_date`
   - Tipo: Rango de fechas

2. **Canal**
   - Campo: `channel_group`
   - Tipo: Lista desplegable

3. **País**
   - Campo: `country`
   - Tipo: Lista desplegable

4. **Dispositivo**
   - Campo: `device_category`
   - Tipo: Lista desplegable

## Paleta de Colores Recomendada

- Primario: `#4285F4` (Google Blue)
- Secundario: `#34A853` (Green)
- Acento: `#FBBC04` (Yellow)
- Error: `#EA4335` (Red)
- Neutral: `#9AA0A6` (Grey)

## Notas de Implementación

1. **Actualización de Datos**: Los dashboards se actualizan automáticamente según el schedule del DAG (2 AM diario)

2. **Permisos**: Compartir dashboards con permisos "Pueden ver" para usuarios finales

3. **Filtros**: Usar controles de filtro para permitir análisis interactivos

4. **Performance**: Para tablas grandes, limitar resultados a Top N o usar filtros de fecha
