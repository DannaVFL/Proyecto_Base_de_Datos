-- =====================================================================
-- 04_limpieza.sql
-- Elimina la tabla temporal del experimento (exp_citas).
-- =====================================================================
USE Prueba_ClinicaLevantateLazaro;
GO
DROP TABLE IF EXISTS exp_citas;
GO

-- Por si exp_citas se creo por error en la base original
USE ClinicaLevantateLazaro;
GO
DROP TABLE IF EXISTS exp_citas;
GO
