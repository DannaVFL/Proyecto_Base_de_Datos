-- =====================================================================
-- 16_planes_evidencias.sql
-- Evidencias: configuracion, planes de ejecucion y tiempo por paso.
-- Ejecutar en A, por bloques. Guardar capturas con fecha y hora visibles.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO

-- ---------- A) CONFIGURACION (carpeta 01_configuracion) ----------
SELECT @@VERSION AS version_sql;

SELECT cpu_count, physical_memory_kb / 1024 AS ram_mb, sqlserver_start_time
FROM sys.dm_os_sys_info;

SELECT name, collation_name, recovery_model_desc, compatibility_level
FROM sys.databases WHERE name IN ('ClinicaLevantateLazaro', 'ClinicaLL_B');

-- Indices de cada base (A no debe tener indices propios en dimensiones; B si)
SELECT 'A' AS bd, t.name AS tabla, i.name AS indice, i.type_desc, i.is_unique
FROM ClinicaLevantateLazaro.sys.indexes i
JOIN ClinicaLevantateLazaro.sys.tables  t ON t.object_id = i.object_id
WHERE i.name IS NOT NULL AND t.name IN ('Dim_Paciente','Dim_Medico','Dim_Especialidad','Dim_EstadoCita','Dim_Tiempo','Fact_Citas')
UNION ALL
SELECT 'B', t.name, i.name, i.type_desc, i.is_unique
FROM ClinicaLL_B.sys.indexes i
JOIN ClinicaLL_B.sys.tables  t ON t.object_id = i.object_id
WHERE i.name IS NOT NULL AND t.name IN ('Dim_Paciente','Dim_Medico','Dim_Especialidad','Dim_EstadoCita','Dim_Tiempo','Fact_Citas')
ORDER BY bd, tabla, indice;

-- ---------- B) PLANES Y TIEMPO POR SENTENCIA (carpeta 06_planes) ----------
-- Procedimiento (solo servidor de pruebas):
--   1. DBCC FREEPROCCACHE;                          -- limpia estadisticas acumuladas
--   2. EXEC etl.usp_PrepararEscenario @escenario='E1_inicial', @proc='etl.usp_EjecutarETL';        -- en A
--      EXEC ClinicaLL_B.etl.usp_PrepararEscenario @escenario='E1_inicial', @proc='etl.usp_EjecutarETL_B';  -- en B
--   3. EXEC etl.usp_EjecutarETL;   y   EXEC ClinicaLL_B.etl.usp_EjecutarETL_B;   (una vez cada uno)
--   4. Ejecutar la consulta de abajo.
-- Muestra el tiempo de CADA sentencia del procedimiento (equivale a "medicion por paso")
-- y su plan. En SSMS, clic en la columna plan_xml abre el plan grafico; "Guardar plan como..." -> .sqlplan
SELECT DB_NAME(st.dbid) AS bd,
       OBJECT_NAME(st.objectid, st.dbid) AS procedimiento,
       qs.statement_start_offset / 2 AS offset_sentencia,
       qs.execution_count,
       qs.last_elapsed_time / 1000.0 AS ms_ultima,
       qs.last_logical_reads         AS lecturas_ultima,
       LEFT(LTRIM(SUBSTRING(st.text, qs.statement_start_offset / 2 + 1,
            (CASE WHEN qs.statement_end_offset = -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END
             - qs.statement_start_offset) / 2 + 1)), 120) AS sentencia,
       TRY_CAST(pq.query_plan AS XML) AS plan_xml
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) pq
WHERE OBJECT_NAME(st.objectid, st.dbid) IN ('usp_EjecutarETL', 'usp_EjecutarETL_B')
ORDER BY bd, qs.statement_start_offset;
-- Buscar la sentencia "INSERT INTO dbo.Fact_Citas": en A se esperan scans de las 5 dimensiones
-- (Nested Loops con Table/Clustered Index Scan); en B, Index Seek / Hash Match con scans baratos.

-- ---------- C) RESULTADOS DE LA EJECUCION (carpeta 04_ejecucion y 05_resultados) ----------
SELECT 'A' AS bd, * FROM ClinicaLevantateLazaro.etl.EjecucionLog ORDER BY idEjecucion DESC OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
SELECT 'B' AS bd, * FROM ClinicaLL_B.etl.EjecucionLog ORDER BY idEjecucion DESC OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

SELECT 'A' AS bd, regla, COUNT(*) AS n FROM ClinicaLevantateLazaro.etl.Rechazos
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM ClinicaLevantateLazaro.etl.EjecucionLog) GROUP BY regla
UNION ALL
SELECT 'B', regla, COUNT(*) FROM ClinicaLL_B.etl.Rechazos
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM ClinicaLL_B.etl.EjecucionLog) GROUP BY regla
ORDER BY bd, regla;

SELECT * FROM etl.Equivalencia ORDER BY id;

-- Corridas completas (exportar a CSV: benchmark.csv)
SELECT * FROM etl.Benchmark ORDER BY idRun;
GO
