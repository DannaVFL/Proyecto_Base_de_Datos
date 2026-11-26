-- =====================================================================
-- 02_experimento_individual.sql
-- Ejecuta UN escenario del experimento.
-- Cambiar el valor de @N en cada ejecucion: 1000, 10000, 50000, 100000
-- Metricas: tiempo de carga (ms), filas por segundo, almacenamiento
-- (sp_spaceused) y memoria usada por SQL Server (MB).
-- =====================================================================
USE Prueba_ClinicaLevantateLazaro;
GO

SET NOCOUNT ON;
DECLARE @N INT = 10000;  -- <-- cambiar aqui

-- Tabla del experimento: misma estructura que stg_citas, vacia
DROP TABLE IF EXISTS exp_citas;
SELECT * INTO exp_citas FROM stg_citas WHERE 1 = 0;

-- Carga de @N registros midiendo el tiempo
DECLARE @t DATETIME2 = SYSDATETIME();

INSERT INTO exp_citas
SELECT TOP (@N) s.*
FROM stg_citas s
CROSS JOIN sys.all_objects a
CROSS JOIN sys.all_objects b;

DECLARE @ms INT = DATEDIFF(MILLISECOND, @t, SYSDATETIME());

-- Resultado 1: tiempo y rendimiento
SELECT @N AS Registros,
       @ms AS Carga_ms,
       CAST(@N * 1000.0 / NULLIF(@ms, 0) AS INT) AS Filas_por_seg;

-- Resultado 2: almacenamiento
EXEC sp_spaceused 'exp_citas';

-- Resultado 3: memoria usada por SQL Server (MB)
SELECT physical_memory_in_use_kb / 1024 AS Memoria_MB
FROM sys.dm_os_process_memory;
