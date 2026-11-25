-- =====================================================================
-- 15_analisis.sql
-- FASE 7. Analizar y decidir. Ejecutar en A, por bloques.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO
SET NOCOUNT ON;

-- 1) Resumen por variante / escenario / volumen (se descarta la corrida 1)
DROP TABLE IF EXISTS #res;

SELECT DISTINCT
       variante, escenario, filas, cache,
       COUNT(*)  OVER (PARTITION BY variante, escenario, filas, cache) AS corridas,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ms)
                 OVER (PARTITION BY variante, escenario, filas, cache) AS mediana_ms,
       AVG(ms)   OVER (PARTITION BY variante, escenario, filas, cache) AS promedio_ms,
       MIN(ms)   OVER (PARTITION BY variante, escenario, filas, cache) AS min_ms,
       MAX(ms)   OVER (PARTITION BY variante, escenario, filas, cache) AS max_ms,
       AVG(CAST(cpu_ms AS FLOAT))           OVER (PARTITION BY variante, escenario, filas, cache) AS cpu_prom_ms,
       AVG(CAST(lecturas_logicas AS FLOAT)) OVER (PARTITION BY variante, escenario, filas, cache) AS lecturas_prom
INTO #res
FROM etl.Benchmark
WHERE corrida > 1;

SELECT * FROM #res ORDER BY escenario, filas, cache, variante;

-- 2) Comparacion A vs B: factor de mejora y % de reduccion (sobre la mediana)
DROP TABLE IF EXISTS #cmp;

SELECT a.escenario, a.filas, a.cache,
       CAST(a.mediana_ms AS DECIMAL(14,1)) AS mediana_A_ms,
       CAST(b.mediana_ms AS DECIMAL(14,1)) AS mediana_B_ms,
       CAST(a.mediana_ms / NULLIF(b.mediana_ms, 0) AS DECIMAL(10,2))                 AS factor_mejora,
       CAST(100.0 * (a.mediana_ms - b.mediana_ms) / NULLIF(a.mediana_ms, 0) AS DECIMAL(6,2)) AS reduccion_pct,
       CAST(a.lecturas_prom AS DECIMAL(18,0)) AS lecturas_A,
       CAST(b.lecturas_prom AS DECIMAL(18,0)) AS lecturas_B
INTO #cmp
FROM #res a
JOIN #res b ON b.escenario = a.escenario AND b.filas = a.filas AND b.cache = a.cache
           AND b.variante = 'B'
WHERE a.variante = 'A';

SELECT * FROM #cmp ORDER BY escenario, filas, cache;

-- 3) Datos para el grafico tiempo vs filas (copiar a Excel, o usar analisis_grafico.py)
SELECT escenario, filas, variante, mediana_ms FROM #res WHERE cache = 'tibia' ORDER BY escenario, variante, filas;

-- 4) Regla de decision (editar los umbrales ANTES de medir, no despues)
DECLARE @umbral_pct DECIMAL(6,2) = 50;       -- reduccion minima de la mediana
DECLARE @min_filas  INT          = 100000;   -- volumen desde el cual se exige el umbral
DECLARE @c1 BIT, @c2 BIT;

-- Criterio 1 (tiempo): E1, cache tibia, todos los volumenes >= @min_filas con reduccion >= umbral
SET @c1 = CASE WHEN EXISTS (SELECT 1 FROM #cmp WHERE escenario = 'E1_inicial' AND cache = 'tibia' AND filas >= @min_filas)
                AND NOT EXISTS (SELECT 1 FROM #cmp WHERE escenario = 'E1_inicial' AND cache = 'tibia' AND filas >= @min_filas
                                  AND reduccion_pct < @umbral_pct)
               THEN 1 ELSE 0 END;

-- Criterio 2 (equivalencia): todas las pruebas de etl.Equivalencia en OK
SET @c2 = CASE WHEN EXISTS (SELECT 1 FROM etl.Equivalencia)
                AND NOT EXISTS (SELECT 1 FROM etl.Equivalencia WHERE resultado <> 'OK')
               THEN 1 ELSE 0 END;

SELECT @c1 AS criterio1_tiempo, @c2 AS criterio2_equivalencia,
       CASE WHEN @c1 = 1 AND @c2 = 1 THEN 'HIPOTESIS VALIDADA'
            WHEN @c1 = 1 AND @c2 = 0 THEN 'REFUTADA: B es mas rapida pero cambia resultados'
            WHEN @c1 = 0 AND @c2 = 1 THEN 'REFUTADA: B es equivalente pero no alcanza el umbral (revisar planes)'
            ELSE 'REFUTADA' END AS conclusion;

-- Si no hay corridas con filas >= @min_filas, criterio1 = 0 porque falta medir esos volumenes.

-- 5) Corridas con error o con conteos distintos entre variantes (deberia devolver 0 filas)
SELECT a.escenario, a.filas, a.corrida,
       a.cargadas AS cargadas_A, b.cargadas AS cargadas_B,
       a.rechazadas AS rech_A,  b.rechazadas AS rech_B
FROM etl.Benchmark a
JOIN etl.Benchmark b ON b.escenario = a.escenario AND b.filas = a.filas AND b.corrida = a.corrida
                    AND b.cache = a.cache AND b.variante = 'B'
WHERE a.variante = 'A'
  AND (a.estado <> 'OK' OR b.estado <> 'OK' OR a.cargadas <> b.cargadas OR a.rechazadas <> b.rechazadas);

-- 6) Para exportar etl.Benchmark completo (las 10 corridas) a CSV:
--    SSMS: ejecutar SELECT * FROM etl.Benchmark ORDER BY idRun; clic derecho en resultados >
--    "Guardar resultados como..." > benchmark.csv  (con encabezados)
GO
