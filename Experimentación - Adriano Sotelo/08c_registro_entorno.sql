-- =====================================================================
-- 08c_registro_entorno.sql
-- Punto 5: registra version de SQL Server, CPU, RAM y collation.
-- Ejecutar en A (una vez, antes de medir). Guarda una captura de los
-- resultados y deja los datos en etl.EntornoPrueba como evidencia.
-- Mide siempre en el mismo servidor y sin otras cargas.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO

-- 1) Resultados para captura
SELECT @@VERSION AS version_sql;

SELECT cpu_count          AS cpu_logicas,
       physical_memory_kb / 1024 AS ram_mb,
       sqlserver_start_time      AS inicio_servicio
FROM sys.dm_os_sys_info;

SELECT 'A' AS bd, DB_NAME() AS base,
       DATABASEPROPERTYEX('ClinicaLevantateLazaro', 'Collation') AS collation_base
UNION ALL
SELECT 'B', 'ClinicaLL_B', DATABASEPROPERTYEX('ClinicaLL_B', 'Collation');

SELECT SERVERPROPERTY('Collation') AS collation_servidor,
       SERVERPROPERTY('Edition')   AS edicion;

SELECT name AS base, recovery_model_desc, compatibility_level
FROM sys.databases
WHERE name IN ('ClinicaLevantateLazaro', 'ClinicaLL_B');

-- Otras sesiones activas en el servidor (deberia aparecer solo la tuya)
SELECT session_id, login_name, status, program_name
FROM sys.dm_exec_sessions
WHERE is_user_process = 1 AND session_id <> @@SPID;

-- 2) Guardar como evidencia en una tabla
IF OBJECT_ID('etl.EntornoPrueba') IS NULL
CREATE TABLE etl.EntornoPrueba (
    fecha  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    clave  VARCHAR(40)   NOT NULL,
    valor  NVARCHAR(500) NULL);

INSERT INTO etl.EntornoPrueba (clave, valor)
SELECT 'version_sql', @@VERSION
UNION ALL SELECT 'cpu_logicas', CAST(cpu_count AS NVARCHAR(20)) FROM sys.dm_os_sys_info
UNION ALL SELECT 'ram_mb', CAST(physical_memory_kb / 1024 AS NVARCHAR(20)) FROM sys.dm_os_sys_info
UNION ALL SELECT 'collation_A', CAST(DATABASEPROPERTYEX('ClinicaLevantateLazaro', 'Collation') AS NVARCHAR(100))
UNION ALL SELECT 'collation_B', CAST(DATABASEPROPERTYEX('ClinicaLL_B', 'Collation') AS NVARCHAR(100))
UNION ALL SELECT 'collation_servidor', CAST(SERVERPROPERTY('Collation') AS NVARCHAR(100));

SELECT * FROM etl.EntornoPrueba ORDER BY fecha DESC, clave;
GO
