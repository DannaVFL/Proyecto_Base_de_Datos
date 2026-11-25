-- =====================================================================
-- 17_limpieza.sql
-- Al terminar el experimento. Ejecutar en A, por bloques.
-- Las mediciones dejaron A con datos generados: este script lo devuelve
-- a su estado original (CSV real).
-- =====================================================================
USE ClinicaLevantateLazaro;
GO

-- 1) Restaurar A: DW vacio + staging original + ETL original
EXEC etl.usp_ResetDW;
EXEC etl.usp_CargarStaging @version = 'ORIGINAL';
EXEC etl.usp_EjecutarETL;
SELECT COUNT(*) AS filas_fact FROM dbo.Fact_Citas;
SELECT COUNT(*) AS filas_staging FROM dbo.stg_citas;
GO

-- 2) (Opcional) Borrar tablas auxiliares de volumen, que pueden ser muy grandes.
--    NO borrar etl.Benchmark ni etl.Equivalencia hasta haber exportado y guardado las evidencias.
-- DROP TABLE IF EXISTS dbo.pool_base, dbo.pool_delta, dbo.pool_sucio;
-- DROP TABLE IF EXISTS ClinicaLL_B.dbo.pool_base, ClinicaLL_B.dbo.pool_delta, ClinicaLL_B.dbo.pool_sucio;

-- 3) (Opcional) Eliminar la base de pruebas B cuando ya no se necesite
-- USE master;
-- ALTER DATABASE ClinicaLL_B SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE ClinicaLL_B;
GO
