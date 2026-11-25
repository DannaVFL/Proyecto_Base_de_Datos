-- =====================================================================
-- 12_linea_base_A.sql
-- FASE 3 (compuerta 1). Validar la linea base con el ETL ORIGINAL y el CSV real.
-- Ejecutar en A, por bloques (seleccionar y F5).
-- Si algo no cuadra, corregirlo ANTES de medir.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO

-- 1) Estado del staging cargado desde el CSV
SELECT COUNT(*) AS filas_staging FROM dbo.stg_citas;                       -- esperado: 1000

-- 1b) Retorno de carro (CRLF) pegado a la ultima columna: si > 0, el BULK INSERT leyo mal
SELECT SUM(CASE WHEN costo LIKE '%' + CHAR(13) + '%' THEN 1 ELSE 0 END) AS costo_con_CR
FROM dbo.stg_citas;
-- Si costo_con_CR > 0: opcion 1) recargar con ROWTERMINATOR = '0x0d0a'
--                      opcion 2) UPDATE dbo.stg_citas SET costo = REPLACE(costo, CHAR(13), '');
--                      (y regenerar dbo.stg_citas_orig a partir de la tabla corregida)

SELECT TOP 10 * FROM dbo.stg_citas ORDER BY id_cita;

-- 2) Ejecutar el ETL original y revisar el resultado
EXEC etl.usp_EjecutarETL;

SELECT TOP 1 * FROM etl.EjecucionLog ORDER BY idEjecucion DESC;

SELECT regla, COUNT(*) AS n
FROM etl.Rechazos
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog)
GROUP BY regla ORDER BY regla;

SELECT COUNT(*) AS filas_fact FROM dbo.Fact_Citas;
-- El script 06 comenta "debe dar 39" pero el CSV tiene 1000 filas.
-- Confirmar que los rechazos (1000 - filas_fact) son legitimos segun las reglas R-01..R-07.

-- Reconciliacion leidas = cargadas + rechazadas
SELECT idEjecucion, filas_leidas, filas_cargadas, filas_rechazadas,
       filas_cargadas + filas_rechazadas AS cargadas_mas_rechazadas
FROM etl.EjecucionLog WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog);
GO

-- 3) Molde para el generador de volumen: filas VALIDAS de esta ejecucion
--    (valores ya limpios; el generador les agrega ruido y suciedad controlados)
IF OBJECT_ID('dbo.stg_plantilla') IS NOT NULL DROP TABLE dbo.stg_plantilla;

SELECT ROW_NUMBER() OVER (ORDER BY row_id) AS rn,
       fecha, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
INTO dbo.stg_plantilla
FROM etl.CitaTrabajo
WHERE es_rechazado = 0;

SELECT COUNT(*) AS filas_plantilla FROM dbo.stg_plantilla;                  -- debe ser > 0
GO

-- 4) Generar el volumen de la prueba de equivalencia (1000 filas) y copiarlo a B
EXEC etl.usp_GenerarPools @filas = 1000;
EXEC etl.usp_CopiarPoolsAB;
GO
