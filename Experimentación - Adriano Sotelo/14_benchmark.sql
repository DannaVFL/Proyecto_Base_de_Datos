-- =====================================================================
-- 14_benchmark.sql
-- FASE 5 y 6. Preparar volumen y ejecutar las mediciones.
-- Ejecutar en A. Se repite UNA VEZ POR VOLUMEN: 1000, 10000, 100000, 500000.
--
-- Cada corrida: prepara el escenario (no se mide) -> mide el ETL -> guarda en etl.Benchmark.
-- Las variantes A y B se ALTERNAN en cada corrida (impar: A,B; par: B,A) para no sesgar
-- por cache u hora. La corrida 1 (compilacion del plan) se guarda pero el analisis la descarta.
--
-- Aviso de tiempo: A con 500000 filas puede tardar mucho por corrida. Pruebe primero con
-- @corridas = 3 en el volumen mayor para estimar, y use 10 en los demas.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO
SET NOCOUNT ON;

-- ---------- PARAMETROS (editar) ----------
DECLARE @filas           INT         = 1000;    -- 1000 | 10000 | 100000 | 500000
DECLARE @corridas        INT         = 10;
DECLARE @fria            BIT         = 0;       -- 0 = cache tibia, 1 = fria (solo servidor de pruebas, requiere sysadmin)
DECLARE @solo_escenario  VARCHAR(20) = NULL;    -- NULL = los 4; o 'E1_inicial' | 'E2_sin_cambios' | 'E3_delta' | 'E4_sucio'
DECLARE @generar         BIT         = 1;       -- 1 = generar y copiar los pools de este volumen
-- -----------------------------------------

IF @generar = 1
BEGIN
    EXEC etl.usp_GenerarPools @filas = @filas;     -- crea pool_base / pool_delta / pool_sucio en A
    EXEC etl.usp_CopiarPoolsAB;                    -- copia identica a B
END;

DECLARE @esc TABLE (orden INT IDENTITY(1,1), e VARCHAR(20));
INSERT @esc (e) VALUES ('E1_inicial'), ('E2_sin_cambios'), ('E3_delta'), ('E4_sucio');

DECLARE @e VARCHAR(20), @i INT;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT e FROM @esc WHERE @solo_escenario IS NULL OR e = @solo_escenario ORDER BY orden;
OPEN cur;
FETCH NEXT FROM cur INTO @e;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @i = 1;
    WHILE @i <= @corridas
    BEGIN
        IF @i % 2 = 1
        BEGIN
            EXEC etl.usp_EjecutarMedicion @variante = 'A', @escenario = @e, @corrida = @i, @fria = @fria;
            EXEC etl.usp_EjecutarMedicion @variante = 'B', @escenario = @e, @corrida = @i, @fria = @fria;
        END
        ELSE
        BEGIN
            EXEC etl.usp_EjecutarMedicion @variante = 'B', @escenario = @e, @corrida = @i, @fria = @fria;
            EXEC etl.usp_EjecutarMedicion @variante = 'A', @escenario = @e, @corrida = @i, @fria = @fria;
        END;
        SET @i += 1;
    END;
    FETCH NEXT FROM cur INTO @e;
END;
CLOSE cur;
DEALLOCATE cur;

-- Control rapido de lo medido en este volumen
SELECT variante, escenario, filas, cache, COUNT(*) AS corridas,
       MIN(ms) AS min_ms, MAX(ms) AS max_ms,
       SUM(CASE WHEN estado <> 'OK' THEN 1 ELSE 0 END) AS corridas_con_error
FROM etl.Benchmark
WHERE filas = @filas
GROUP BY variante, escenario, filas, cache
ORDER BY escenario, variante;
GO
