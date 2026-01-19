-- =========================================================
-- Dataform Macros
-- Macros reutilizables para transformaciones
-- =========================================================

-- Macro para particionado por fecha
macro partition_by_date(date_column)
  PARTITION BY {{ date_column }}
end

-- Macro para clustering
macro cluster_by(columns)
  CLUSTER BY {{ columns }}
end

-- Macro para incremental MERGE
macro incremental_merge(
  target_table,
  source_query,
  unique_key,
  partition_date
)
  MERGE {{ target_table }} AS target
  USING (
    {{ source_query }}
  ) AS source
  ON target.{{ unique_key }} = source.{{ unique_key }}
  WHEN MATCHED THEN
    UPDATE SET *
  WHEN NOT MATCHED THEN
    INSERT *
end

-- Macro para extraer event_param
macro get_event_param(param_key, param_type)
  (
    SELECT 
      CASE 
        WHEN '{{ param_type }}' = 'string' THEN value.string_value
        WHEN '{{ param_type }}' = 'int' THEN CAST(value.int_value AS STRING)
        WHEN '{{ param_type }}' = 'double' THEN CAST(value.double_value AS STRING)
        ELSE value.string_value
      END
    FROM UNNEST(event_params) 
    WHERE key = '{{ param_key }}'
  )
end

-- Macro para generar hash key
macro generate_key(columns)
  TO_HEX(SHA256(CONCAT(
    {{ columns }}
  )))
end
