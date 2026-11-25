-- =====================================================================
-- 09_respaldo_restaurar_B.sql
-- FASE 2 (entorno). Respalda A y la restaura como ClinicaLL_B.
-- Ejecutar DESPUES de 08_utilidades_A.sql.
-- EDITAR @bak: la carpeta debe existir y SQL Server debe poder escribir en ella.
-- Supone 1 archivo de datos y 1 de log. Si A tiene mas, agregue MOVE por cada uno.
-- =====================================================================
USE master;
GO

DECLARE @bak    NVARCHAR(260) = N'C:\ETL\ClinicaLL_A.bak';
DECLARE @dir    NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @logdir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(260));
DECLARE @d SYSNAME, @l SYSNAME, @sql NVARCHAR(MAX);

SELECT @d = name FROM sys.master_files WHERE database_id = DB_ID('ClinicaLevantateLazaro') AND type = 0;
SELECT @l = name FROM sys.master_files WHERE database_id = DB_ID('ClinicaLevantateLazaro') AND type = 1;

BACKUP DATABASE ClinicaLevantateLazaro TO DISK = @bak WITH INIT, COPY_ONLY, STATS = 10;

SET @sql = N'RESTORE DATABASE ClinicaLL_B FROM DISK = N''' + @bak + N''' WITH REPLACE, STATS = 10, '
         + N'MOVE N''' + @d + N''' TO N''' + @dir    + N'ClinicaLL_B.mdf'', '
         + N'MOVE N''' + @l + N''' TO N''' + @logdir + N'ClinicaLL_B_log.ldf'';';
EXEC (@sql);
GO

-- Verificacion: ambas bases deben tener la misma collation y modelo de recuperacion
SELECT name, collation_name, recovery_model_desc, compatibility_level
FROM sys.databases
WHERE name IN ('ClinicaLevantateLazaro', 'ClinicaLL_B');
GO
