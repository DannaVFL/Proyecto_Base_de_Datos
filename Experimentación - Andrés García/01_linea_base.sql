-- =====================================================================
-- 01_linea_base.sql
-- Cantidad de registros por tabla en la base de prueba.
-- Es el punto de partida (linea base) del experimento.
-- =====================================================================
USE Prueba_ClinicaLevantateLazaro;
GO

SELECT t.name AS Tabla, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY Filas DESC;
