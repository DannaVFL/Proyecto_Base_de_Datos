-- Prueba de control de errores: inserta registros sucios en staging,
-- ejecuta el ETL y restaura los datos originales.
-- Ejecutar por bloques (seleccionar cada bloque y pulsar F5).
USE ClinicaLevantateLazaro;
GO

-- 1) Respaldo de staging (solo si no existe)
IF OBJECT_ID('dbo.stg_citas_bak') IS NULL
    SELECT * INTO dbo.stg_citas_bak FROM dbo.stg_citas;

-- 2) Registros sucios (uno por regla)
-- R-01 campo obligatorio nulo
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 9001, fecha, NULL, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-02 id_cita duplicado
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-03 DNI invalido
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 9003, fecha, 'ABC-XX', nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-04 estado fuera de catalogo
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 9004, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, 'Inexistente', duracion_min, costo
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-05 fecha invalida
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 9005, '2026-13-45', dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-06 duracion invalida (tambien costo negativo)
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT TOP 1 9006, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, '-30', '-50'
FROM dbo.stg_citas_bak ORDER BY id_cita;
-- R-07 costo invalido con duracion valida (opcional)
-- INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
-- SELECT TOP 1 9007, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, '-50'
-- FROM dbo.stg_citas_bak ORDER BY id_cita;

-- 3) Ejecutar el ETL y ver resultados
EXEC etl.usp_EjecutarETL;

SELECT TOP 1 * FROM etl.EjecucionLog ORDER BY idEjecucion DESC;

SELECT metrica,
       MAX(CASE WHEN etapa = 'ANTES'   THEN valor END) AS antes,
       MAX(CASE WHEN etapa = 'DESPUES' THEN valor END) AS despues
FROM etl.CalidadMetricas
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog)
GROUP BY metrica ORDER BY metrica;

SELECT * FROM etl.Rechazos
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog);

-- 4) Restaurar staging a los datos originales y recargar
TRUNCATE TABLE dbo.stg_citas;
INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
FROM dbo.stg_citas_bak WHERE id_cita < 9000;

EXEC etl.usp_EjecutarETL;
SELECT COUNT(*) AS filas_fact FROM dbo.Fact_Citas;   -- debe dar 39
