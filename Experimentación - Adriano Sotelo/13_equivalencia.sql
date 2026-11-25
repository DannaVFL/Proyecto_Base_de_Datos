-- =====================================================================
-- 13_equivalencia.sql
-- FASE 4 (compuerta 2). Valida que B produce EXACTAMENTE lo mismo que A:
-- hecho, rechazos, metricas de calidad y log.
-- Casos: CSV real, base generada, datos sucios (R-01..R-07), delta
-- (incremental) y re-ejecucion sin cambios.
-- Requisito: 12_linea_base_A.sql ejecutado (pools de 1000 filas ya copiados a B).
-- Ejecutar en A. Si algun resultado es FALLA, NO pasar a medir: corregir B.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO
SET NOCOUNT ON;

TRUNCATE TABLE etl.Equivalencia;

DECLARE @casos TABLE (orden INT, etiqueta VARCHAR(60), v1 VARCHAR(10), v2 VARCHAR(10));
INSERT @casos VALUES
    (1, 'CSV real (ORIGINAL)',               'ORIGINAL', NULL),
    (2, 'Base generada',                     'BASE',     NULL),
    (3, 'Datos sucios R-01..R-07',           'SUCIO',    NULL),
    (4, 'Delta: 5% nuevas + 2% cambios',     'BASE',     'DELTA'),
    (5, 'Re-ejecucion sin cambios',          'BASE',     'BASE');

DECLARE @etq VARCHAR(60), @v1 VARCHAR(10), @v2 VARCHAR(10);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT etiqueta, v1, v2 FROM @casos ORDER BY orden;
OPEN cur;
FETCH NEXT FROM cur INTO @etq, @v1, @v2;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Mismo estado inicial en ambas bases
    EXEC ClinicaLevantateLazaro.etl.usp_ResetDW;
    EXEC ClinicaLL_B.etl.usp_ResetDW;

    -- Primera carga
    EXEC ClinicaLevantateLazaro.etl.usp_CargarStaging @version = @v1;
    EXEC ClinicaLL_B.etl.usp_CargarStaging            @version = @v1;
    EXEC ClinicaLevantateLazaro.etl.usp_EjecutarETL;
    EXEC ClinicaLL_B.etl.usp_EjecutarETL_B;

    -- Segunda carga (delta / re-ejecucion), si el caso la tiene
    IF @v2 IS NOT NULL
    BEGIN
        EXEC ClinicaLevantateLazaro.etl.usp_CargarStaging @version = @v2;
        EXEC ClinicaLL_B.etl.usp_CargarStaging            @version = @v2;
        EXEC ClinicaLevantateLazaro.etl.usp_EjecutarETL;
        EXEC ClinicaLL_B.etl.usp_EjecutarETL_B;
    END;

    EXEC ClinicaLevantateLazaro.etl.usp_CompararAB @etiqueta = @etq;

    FETCH NEXT FROM cur INTO @etq, @v1, @v2;
END;
CLOSE cur;
DEALLOCATE cur;

-- Resumen final (guardar captura como evidencia)
SELECT etiqueta, prueba, diferencias, resultado FROM etl.Equivalencia ORDER BY id;

SELECT CASE WHEN EXISTS (SELECT 1 FROM etl.Equivalencia WHERE resultado <> 'OK')
            THEN 'EQUIVALENCIA: FALLA -> corregir B antes de medir'
            ELSE 'EQUIVALENCIA: OK -> se puede pasar a la fase de medicion' END AS veredicto;

-- Si hay FALLA, inspeccionar el detalle, por ejemplo:
-- SELECT * FROM ClinicaLevantateLazaro.dbo.vw_FactPlano
-- EXCEPT SELECT * FROM ClinicaLL_B.dbo.vw_FactPlano;
-- Causa tipica: variantes con/sin tilde en nombres de especialidad o medico (collation).
GO
