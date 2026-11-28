SET NOCOUNT ON;

-- Mes con mas citas (se usa el mismo mes en todas las pruebas)
DECLARE @anio INT, @mes INT;
SELECT TOP 1 @anio = t.anio, @mes = t.mes
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.id_tiempo = f.id_tiempo
GROUP BY t.anio, t.mes
ORDER BY COUNT(*) DESC;

-- Tablas de prueba (datos sinteticos: filas replicadas de Fact_Citas)
DROP TABLE IF EXISTS dbo.Exp_Fact_960, dbo.Exp_Fact_10k, dbo.Exp_Fact_100k;

SELECT id_tiempo, duracion_min, costo_consulta
INTO dbo.Exp_Fact_960
FROM dbo.Fact_Citas;

SELECT TOP (10000) f.id_tiempo, f.duracion_min, f.costo_consulta
INTO dbo.Exp_Fact_10k
FROM dbo.Fact_Citas f
CROSS JOIN (SELECT TOP (11) 1 AS n FROM sys.all_objects) x;

SELECT TOP (100000) f.id_tiempo, f.duracion_min, f.costo_consulta
INTO dbo.Exp_Fact_100k
FROM dbo.Fact_Citas f
CROSS JOIN (SELECT TOP (105) 1 AS n FROM sys.all_objects) x;

-- Mediciones
CREATE TABLE #tiempos (
    tabla SYSNAME, rep INT, ms DECIMAL(12,3),
    citas INT, dur_prom FLOAT, costo DECIMAL(18,2)
);

DECLARE @tablas TABLE (nombre SYSNAME);
INSERT @tablas VALUES ('Exp_Fact_960'), ('Exp_Fact_10k'), ('Exp_Fact_100k');

DECLARE @t SYSNAME, @sql NVARCHAR(MAX), @i INT;
DECLARE @ini DATETIME2(7), @fin DATETIME2(7);
DECLARE @c INT, @d FLOAT, @k DECIMAL(18,2);

DECLARE cur CURSOR FOR SELECT nombre FROM @tablas;
OPEN cur;
FETCH NEXT FROM cur INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'SELECT @c = COUNT(*), @d = AVG(CAST(f.duracion_min AS FLOAT)), @k = SUM(f.costo_consulta)
                 FROM dbo.' + QUOTENAME(@t) + N' f
                 JOIN dbo.Dim_Tiempo t ON t.id_tiempo = f.id_tiempo
                 WHERE t.anio = @anio AND t.mes = @mes';

    -- Calentamiento (no se guarda)
    EXEC sp_executesql @sql,
         N'@anio INT, @mes INT, @c INT OUTPUT, @d FLOAT OUTPUT, @k DECIMAL(18,2) OUTPUT',
         @anio, @mes, @c OUTPUT, @d OUTPUT, @k OUTPUT;

    SET @i = 1;
    WHILE @i <= 5
    BEGIN
        SET @ini = SYSDATETIME();
        EXEC sp_executesql @sql,
             N'@anio INT, @mes INT, @c INT OUTPUT, @d FLOAT OUTPUT, @k DECIMAL(18,2) OUTPUT',
             @anio, @mes, @c OUTPUT, @d OUTPUT, @k OUTPUT;
        SET @fin = SYSDATETIME();
        INSERT #tiempos VALUES (@t, @i, DATEDIFF_BIG(MICROSECOND, @ini, @fin) / 1000.0, @c, @d, @k);
        SET @i += 1;
    END;

    FETCH NEXT FROM cur INTO @t;
END;
CLOSE cur;
DEALLOCATE cur;

-- Resultados
SELECT @anio AS anio_consultado, @mes AS mes_consultado;

SELECT 'Exp_Fact_960' AS tabla, COUNT(*) AS filas FROM dbo.Exp_Fact_960
UNION ALL SELECT 'Exp_Fact_10k', COUNT(*) FROM dbo.Exp_Fact_10k
UNION ALL SELECT 'Exp_Fact_100k', COUNT(*) FROM dbo.Exp_Fact_100k;

SELECT tabla,
       MAX(citas) AS citas_del_mes,
       ROUND(MAX(dur_prom), 4) AS duracion_promedio,
       MAX(costo) AS costo_total,
       COUNT(*) AS repeticiones,
       ROUND(AVG(ms), 3) AS promedio_ms,
       MIN(ms) AS min_ms,
       MAX(ms) AS max_ms,
       ROUND(STDEV(ms), 3) AS desv_ms
FROM #tiempos
GROUP BY tabla
ORDER BY MAX(citas);

SELECT tabla, rep, ms FROM #tiempos ORDER BY tabla, rep;