-- =====================================================================
-- 03_experimento_4_escenarios.sql
-- Ejecuta los 4 escenarios seguidos (1000, 10000, 50000 y 100000
-- registros) y muestra una sola tabla final con las metricas.
-- =====================================================================
USE Prueba_ClinicaLevantateLazaro;
GO

SET NOCOUNT ON;
DECLARE @res TABLE (Registros INT, Carga_ms INT, Filas_por_seg INT,
                    Reservado_KB INT, Memoria_MB INT);
DECLARE @vals TABLE (n INT);
INSERT INTO @vals VALUES (1000),(10000),(50000),(100000);

DECLARE @N INT, @t DATETIME2, @ms INT;
DECLARE c CURSOR FOR SELECT n FROM @vals ORDER BY n;
OPEN c;
FETCH NEXT FROM c INTO @N;

WHILE @@FETCH_STATUS = 0
BEGIN
    DROP TABLE IF EXISTS exp_citas;
    SELECT * INTO exp_citas FROM stg_citas WHERE 1 = 0;

    SET @t = SYSDATETIME();
    INSERT INTO exp_citas
    SELECT TOP (@N) s.*
    FROM stg_citas s
    CROSS JOIN sys.all_objects a
    CROSS JOIN sys.all_objects b;
    SET @ms = DATEDIFF(MILLISECOND, @t, SYSDATETIME());

    INSERT INTO @res
    SELECT @N, @ms,
           CAST(@N * 1000.0 / NULLIF(@ms, 0) AS INT),
           (SELECT SUM(reserved_page_count) * 8
            FROM sys.dm_db_partition_stats
            WHERE object_id = OBJECT_ID('exp_citas')),
           (SELECT physical_memory_in_use_kb / 1024
            FROM sys.dm_os_process_memory);

    FETCH NEXT FROM c INTO @N;
END

CLOSE c;
DEALLOCATE c;

SELECT * FROM @res ORDER BY Registros;
