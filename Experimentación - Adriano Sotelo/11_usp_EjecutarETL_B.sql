USE ClinicaLL_B;
GO
-- =====================================================================
-- 11_usp_EjecutarETL_B.sql
-- FASE 2 (entorno). Variante OPTIMIZADA (B) del procedimiento original.
-- Cambios respecto a etl.usp_EjecutarETL (todo lo demas es identico):
--   1) Joins directos contra las dimensiones: sin COLLATE ni CROSS APPLY TOP 1
--      (la collation CI_AI ya esta en las columnas, ver 10_preparar_B.sql).
--   2) MERGE de dimensiones reemplazado por UPDATE + INSERT ... WHERE NOT EXISTS.
--   3) Hecho INCREMENTAL: UPDATE de citas cambiadas e INSERT de citas nuevas,
--      sin DELETE FROM Fact_Citas.
-- Definicion de filas_cargadas: igual que en A (filas validas presentes en el hecho),
-- asi la reconciliacion leidas = cargadas + rechazadas es la misma en ambas variantes.
-- Detalle nuevas / actualizadas / sin cambio queda en EjecucionLog.mensaje.
-- =====================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [etl].[usp_EjecutarETL_B]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id INT, @leidas INT = 0, @rech INT = 0, @cargadas INT = 0;
    DECLARE @nuevas INT = 0, @actualizadas INT = 0, @sin_cambio INT = 0;
    DECLARE @sal VARCHAR(30) = 'CLINICA-LL-2026|';   -- sal fija para el hash

    INSERT INTO etl.EjecucionLog (proceso) VALUES ('ETL_Citas_B');
    SET @id = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;

        /* 1) EXTRACCIÓN: stg_citas -> tabla de trabajo */
        TRUNCATE TABLE etl.CitaTrabajo;
        INSERT INTO etl.CitaTrabajo
            (id_cita, fecha_raw, dni_raw, nombre_paciente, cod_medico, nombre_medico,
             especialidad, estado, duracion_raw, costo_raw)
        SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico,
               especialidad, estado, duracion_min, costo
        FROM dbo.stg_citas;
        SET @leidas = @@ROWCOUNT;

        /* 2) LIMPIEZA y conversión de tipos (idéntico a A) */
        UPDATE etl.CitaTrabajo SET
            normalizada = CASE WHEN estado COLLATE Latin1_General_CS_AS <> UPPER(LTRIM(RTRIM(estado)))
                                 OR DATALENGTH(estado) <> DATALENGTH(LTRIM(RTRIM(estado)))
                                 OR cod_medico COLLATE Latin1_General_CS_AS <> UPPER(LTRIM(RTRIM(cod_medico)))
                                 OR especialidad COLLATE Latin1_General_CS_AS <> UPPER(LTRIM(RTRIM(especialidad)))
                                 OR DATALENGTH(dni_raw) <> DATALENGTH(LTRIM(RTRIM(dni_raw)))
                                 OR (TRY_CONVERT(DATE, LTRIM(RTRIM(fecha_raw)), 23) IS NULL
                                     AND TRY_CONVERT(DATE, LTRIM(RTRIM(fecha_raw)), 103) IS NOT NULL)
                                 OR costo_raw LIKE '%[^0-9.]%'
                               THEN 1 ELSE 0 END,
            dni             = NULLIF(LTRIM(RTRIM(dni_raw)), ''),
            nombre_paciente = UPPER(NULLIF(LTRIM(RTRIM(nombre_paciente)), '')),
            cod_medico      = UPPER(NULLIF(LTRIM(RTRIM(cod_medico)), '')),
            nombre_medico   = UPPER(NULLIF(LTRIM(RTRIM(nombre_medico)), '')),
            especialidad    = UPPER(NULLIF(LTRIM(RTRIM(especialidad)), '')),
            estado          = UPPER(NULLIF(LTRIM(RTRIM(estado)), '')),
            fecha           = COALESCE(TRY_CONVERT(DATE, LTRIM(RTRIM(fecha_raw)), 23),
                                       TRY_CONVERT(DATE, LTRIM(RTRIM(fecha_raw)), 103)),
            duracion_min    = TRY_CAST(NULLIF(LTRIM(RTRIM(duracion_raw)), '') AS INT),
            costo           = TRY_CAST(NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(costo_raw)), 'S/', ''), ' ', ''), '') AS DECIMAL(10,2));

        /* 3) TRANSFORMACIÓN: seudonimización del DNI (SHA-256 con sal) (idéntico a A) */
        UPDATE etl.CitaTrabajo
           SET dni_hash = CASE WHEN dni IS NOT NULL
                               THEN CONVERT(VARCHAR(100), HASHBYTES('SHA2_256', @sal + dni), 2) END;

        /* 4) PERFILADO: reglas de calidad R-01 a R-07 (idéntico a A) */
        UPDATE etl.CitaTrabajo SET
            r01 = CASE WHEN id_cita IS NULL OR NULLIF(LTRIM(RTRIM(fecha_raw)), '') IS NULL
                         OR dni IS NULL OR cod_medico IS NULL OR especialidad IS NULL OR estado IS NULL
                       THEN 1 ELSE 0 END,
            r03 = CASE WHEN dni IS NOT NULL AND (LEN(dni) <> 8 OR dni LIKE '%[^0-9]%') THEN 1 ELSE 0 END,
            r04 = CASE WHEN estado IS NOT NULL AND estado NOT IN ('ATENDIDA','PROGRAMADA','CANCELADA')
                       THEN 1 ELSE 0 END,
            r05 = CASE WHEN NULLIF(LTRIM(RTRIM(fecha_raw)), '') IS NOT NULL
                        AND (fecha IS NULL OR fecha < '2020-01-01'
                             OR fecha > DATEADD(YEAR, 1, CAST(GETDATE() AS DATE)))
                       THEN 1 ELSE 0 END,
            r06 = CASE WHEN NULLIF(LTRIM(RTRIM(duracion_raw)), '') IS NOT NULL
                        AND (duracion_min IS NULL OR duracion_min <= 0 OR duracion_min > 240)
                       THEN 1 ELSE 0 END,
            r07 = CASE WHEN NULLIF(LTRIM(RTRIM(costo_raw)), '') IS NOT NULL
                        AND (costo IS NULL OR costo < 0)
                       THEN 1 ELSE 0 END;

        ;WITH d AS (
            SELECT row_id,
                   ROW_NUMBER() OVER (PARTITION BY id_cita ORDER BY row_id) AS rn
            FROM etl.CitaTrabajo WHERE id_cita IS NOT NULL
        )
        UPDATE t SET r02 = 1
        FROM etl.CitaTrabajo t JOIN d ON d.row_id = t.row_id
        WHERE d.rn > 1;

        UPDATE etl.CitaTrabajo
           SET es_rechazado = CASE WHEN r01 + r02 + r03 + r04 + r05 + r06 + r07 > 0 THEN 1 ELSE 0 END;

        /* 5) CONTROL DE ERRORES: registrar rechazos por regla (idéntico a A) */
        INSERT INTO etl.Rechazos (idEjecucion, fila_staging, id_cita, regla, detalle)
        SELECT @id, row_id, id_cita, 'R-01', N'Campo obligatorio nulo o vacío' FROM etl.CitaTrabajo WHERE r01 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-02', N'id_cita duplicado'              FROM etl.CitaTrabajo WHERE r02 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-03', N'DNI no tiene 8 dígitos'         FROM etl.CitaTrabajo WHERE r03 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-04', N'Estado fuera de catálogo'       FROM etl.CitaTrabajo WHERE r04 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-05', N'Fecha inválida o fuera de rango' FROM etl.CitaTrabajo WHERE r05 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-06', N'Duración inválida'              FROM etl.CitaTrabajo WHERE r06 = 1
        UNION ALL SELECT @id, row_id, id_cita, 'R-07', N'Costo inválido'                 FROM etl.CitaTrabajo WHERE r07 = 1;

        SELECT @rech = COUNT(*) FROM etl.CitaTrabajo WHERE es_rechazado = 1;

        /* 6) MÉTRICAS "ANTES" (idéntico a A) */
        INSERT INTO etl.CalidadMetricas (idEjecucion, etapa, metrica, valor)
        SELECT @id, 'ANTES', v.metrica, v.valor
        FROM (SELECT COUNT(*) AS n,
                     ISNULL(SUM(CAST(r01 AS INT)), 0) AS a, ISNULL(SUM(CAST(r02 AS INT)), 0) AS b,
                     ISNULL(SUM(CAST(r03 AS INT)), 0) AS c, ISNULL(SUM(CAST(r04 AS INT)), 0) AS d,
                     ISNULL(SUM(CAST(r05 AS INT)), 0) AS e, ISNULL(SUM(CAST(r06 AS INT)), 0) AS f,
                     ISNULL(SUM(CAST(r07 AS INT)), 0) AS g, ISNULL(SUM(CAST(normalizada AS INT)), 0) AS h,
                     ISNULL(SUM(CAST(es_rechazado AS INT)), 0) AS x
              FROM etl.CitaTrabajo) s
        CROSS APPLY (VALUES
            ('registros',            CAST(s.n AS DECIMAL(18,4))),
            ('R01_nulos_criticos',   CAST(s.a AS DECIMAL(18,4))),
            ('R02_duplicados',       CAST(s.b AS DECIMAL(18,4))),
            ('R03_dni_invalido',     CAST(s.c AS DECIMAL(18,4))),
            ('R04_estado_invalido',  CAST(s.d AS DECIMAL(18,4))),
            ('R05_fecha_invalida',   CAST(s.e AS DECIMAL(18,4))),
            ('R06_duracion_invalida',CAST(s.f AS DECIMAL(18,4))),
            ('R07_costo_invalido',   CAST(s.g AS DECIMAL(18,4))),
            ('filas_a_normalizar',   CAST(s.h AS DECIMAL(18,4))),
            ('pct_filas_validas',    CAST(100.0 * (s.n - s.x) / NULLIF(s.n, 0) AS DECIMAL(18,4)))
        ) v(metrica, valor)
        UNION ALL
        SELECT @id, 'ANTES', 'pacientes_sin_seudonimizar', COUNT(*)
        FROM dbo.Dim_Paciente
        WHERE dni IS NOT NULL AND (LEN(dni) <> 64 OR dni COLLATE Latin1_General_BIN LIKE '%[^0-9A-F]%')
        UNION ALL
        SELECT @id, 'ANTES', 'dim_paciente_duplicados', COUNT(dni) - COUNT(DISTINCT LTRIM(RTRIM(dni)))
        FROM dbo.Dim_Paciente;

        /* 7) CARGA DE DIMENSIONES (solo filas válidas) -- CAMBIO 2: sin MERGE, sin COLLATE */
        -- Pacientes: seudonimizar lo existente (idéntico a A) y luego insertar los nuevos
        UPDATE dbo.Dim_Paciente
           SET dni = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @sal + LTRIM(RTRIM(dni))), 2)
         WHERE dni IS NOT NULL AND LEN(dni) <> 64;

        UPDATE dbo.Dim_Paciente
           SET nombre = 'PAC-' + LEFT(dni, 8)
         WHERE dni IS NOT NULL AND LEN(dni) = 64 AND (nombre IS NULL OR nombre NOT LIKE 'PAC-%');

        INSERT INTO dbo.Dim_Paciente (dni, nombre)
        SELECT DISTINCT c.dni_hash, 'PAC-' + LEFT(c.dni_hash, 8)
        FROM etl.CitaTrabajo c
        WHERE c.es_rechazado = 0
          AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Paciente d WHERE d.dni = c.dni_hash);

        -- Médicos: actualizar nombre si cambió (sensible a mayúsculas, como en A) e insertar nuevos
        ;WITH s AS (
            SELECT cod_medico, MAX(nombre_medico) AS nombre
            FROM etl.CitaTrabajo WHERE es_rechazado = 0 GROUP BY cod_medico
        )
        UPDATE d SET nombre = s.nombre
        FROM dbo.Dim_Medico d
        JOIN s ON s.cod_medico = d.cod_medico
        WHERE ISNULL(d.nombre, '') COLLATE Latin1_General_CS_AS <> ISNULL(s.nombre, '');

        INSERT INTO dbo.Dim_Medico (cod_medico, nombre)
        SELECT s.cod_medico, s.nombre
        FROM (SELECT cod_medico, MAX(nombre_medico) AS nombre
              FROM etl.CitaTrabajo WHERE es_rechazado = 0 GROUP BY cod_medico) s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Medico d WHERE d.cod_medico = s.cod_medico);

        INSERT INTO dbo.Dim_Especialidad (nombre)
        SELECT DISTINCT c.especialidad
        FROM etl.CitaTrabajo c
        WHERE c.es_rechazado = 0
          AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Especialidad d WHERE d.nombre = c.especialidad);

        INSERT INTO dbo.Dim_EstadoCita (estado)
        SELECT DISTINCT c.estado
        FROM etl.CitaTrabajo c
        WHERE c.es_rechazado = 0
          AND NOT EXISTS (SELECT 1 FROM dbo.Dim_EstadoCita d WHERE d.estado = c.estado);

        INSERT INTO dbo.Dim_Tiempo (fecha, anio, mes, dia)
        SELECT DISTINCT c.fecha, YEAR(c.fecha), MONTH(c.fecha), DAY(c.fecha)
        FROM etl.CitaTrabajo c
        WHERE c.es_rechazado = 0
          AND NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.fecha = c.fecha);

        /* 8) CARGA DEL HECHO -- CAMBIO 3: incremental (sin DELETE), joins directos */
        -- 8a) Citas ya cargadas que cambiaron
        UPDATE f SET
            id_tiempo       = t.id_tiempo,
            id_paciente     = p.id_paciente,
            id_medico       = m.id_medico,
            id_especialidad = e.id_especialidad,
            id_estado       = s.id_estado,
            duracion_min    = c.duracion_min,
            costo_consulta  = c.costo
        FROM dbo.Fact_Citas f
        JOIN etl.CitaTrabajo      c ON c.id_cita = f.id_cita AND c.es_rechazado = 0
        JOIN dbo.Dim_Tiempo       t ON t.fecha      = c.fecha
        JOIN dbo.Dim_Paciente     p ON p.dni        = c.dni_hash
        JOIN dbo.Dim_Medico       m ON m.cod_medico = c.cod_medico
        JOIN dbo.Dim_Especialidad e ON e.nombre     = c.especialidad
        JOIN dbo.Dim_EstadoCita   s ON s.estado     = c.estado
        WHERE f.id_tiempo       <> t.id_tiempo
           OR f.id_paciente     <> p.id_paciente
           OR f.id_medico       <> m.id_medico
           OR f.id_especialidad <> e.id_especialidad
           OR f.id_estado       <> s.id_estado
           OR ISNULL(f.duracion_min, -1)     <> ISNULL(c.duracion_min, -1)
           OR ISNULL(f.costo_consulta, -1.0) <> ISNULL(c.costo, -1.0);
        SET @actualizadas = @@ROWCOUNT;

        -- 8b) Citas nuevas
        INSERT INTO dbo.Fact_Citas
            (id_cita, id_tiempo, id_paciente, id_medico, id_especialidad, id_estado,
             cantidad_citas, duracion_min, costo_consulta)
        SELECT c.id_cita, t.id_tiempo, p.id_paciente, m.id_medico, e.id_especialidad, s.id_estado,
               1, c.duracion_min, c.costo
        FROM etl.CitaTrabajo c
        JOIN dbo.Dim_Tiempo       t ON t.fecha      = c.fecha
        JOIN dbo.Dim_Paciente     p ON p.dni        = c.dni_hash
        JOIN dbo.Dim_Medico       m ON m.cod_medico = c.cod_medico
        JOIN dbo.Dim_Especialidad e ON e.nombre     = c.especialidad
        JOIN dbo.Dim_EstadoCita   s ON s.estado     = c.estado
        WHERE c.es_rechazado = 0
          AND NOT EXISTS (SELECT 1 FROM dbo.Fact_Citas f WHERE f.id_cita = c.id_cita);
        SET @nuevas = @@ROWCOUNT;

        -- Filas válidas de esta carga que quedaron presentes en el hecho
        SELECT @cargadas = COUNT(*)
        FROM etl.CitaTrabajo c
        WHERE c.es_rechazado = 0
          AND EXISTS (SELECT 1 FROM dbo.Fact_Citas f WHERE f.id_cita = c.id_cita);
        SET @sin_cambio = @cargadas - @nuevas - @actualizadas;

        -- Consolidar pacientes duplicados que quedaron sin uso en el hecho (idéntico a A)
        ;WITH d AS (
            SELECT id_paciente,
                   ROW_NUMBER() OVER (PARTITION BY dni ORDER BY id_paciente) AS rn
            FROM dbo.Dim_Paciente WHERE dni IS NOT NULL
        )
        DELETE p
        FROM dbo.Dim_Paciente p JOIN d ON d.id_paciente = p.id_paciente
        WHERE d.rn > 1
          AND NOT EXISTS (SELECT 1 FROM dbo.Fact_Citas f WHERE f.id_paciente = p.id_paciente);

        /* 9) RECONCILIACIÓN: leídas = cargadas + rechazadas */
        IF @leidas <> @cargadas + @rech
            THROW 50001, 'Reconciliación fallida: leídas <> cargadas + rechazadas', 1;

        /* 10) MÉTRICAS "DESPUÉS" (idéntico a A) */
        ;WITH fx AS (
            SELECT f.id_hecho, f.id_cita, f.id_tiempo, f.id_paciente, f.id_medico,
                   f.id_especialidad, f.id_estado, f.duracion_min, f.costo_consulta,
                   t.fecha, ec.estado, p.dni,
                   ROW_NUMBER() OVER (PARTITION BY f.id_cita ORDER BY f.id_hecho) AS rn
            FROM dbo.Fact_Citas f
            LEFT JOIN dbo.Dim_Tiempo     t  ON t.id_tiempo   = f.id_tiempo
            LEFT JOIN dbo.Dim_EstadoCita ec ON ec.id_estado  = f.id_estado
            LEFT JOIN dbo.Dim_Paciente   p  ON p.id_paciente = f.id_paciente
        ), fl AS (
            SELECT *,
                CASE WHEN id_cita IS NULL OR id_tiempo IS NULL OR id_paciente IS NULL OR id_medico IS NULL
                       OR id_especialidad IS NULL OR id_estado IS NULL THEN 1 ELSE 0 END AS ca,
                CASE WHEN rn > 1 THEN 1 ELSE 0 END AS cb,
                CASE WHEN dni IS NULL OR LEN(dni) <> 64
                       OR dni COLLATE Latin1_General_BIN LIKE '%[^0-9A-F]%' THEN 1 ELSE 0 END AS cc,
                CASE WHEN estado IS NULL OR UPPER(estado) NOT IN ('ATENDIDA','PROGRAMADA','CANCELADA')
                     THEN 1 ELSE 0 END AS cd,
                CASE WHEN fecha IS NULL OR fecha < '2020-01-01'
                       OR fecha > DATEADD(YEAR, 1, CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END AS ce,
                CASE WHEN duracion_min IS NOT NULL AND (duracion_min <= 0 OR duracion_min > 240)
                     THEN 1 ELSE 0 END AS cf,
                CASE WHEN costo_consulta IS NOT NULL AND costo_consulta < 0 THEN 1 ELSE 0 END AS cg
            FROM fx
        ), s AS (
            SELECT COUNT(*) AS n,
                   ISNULL(SUM(ca), 0) AS a, ISNULL(SUM(cb), 0) AS b, ISNULL(SUM(cc), 0) AS c,
                   ISNULL(SUM(cd), 0) AS d, ISNULL(SUM(ce), 0) AS e, ISNULL(SUM(cf), 0) AS f,
                   ISNULL(SUM(cg), 0) AS g,
                   ISNULL(SUM(CASE WHEN ca + cb + cc + cd + ce + cf + cg > 0 THEN 1 ELSE 0 END), 0) AS x
            FROM fl
        )
        INSERT INTO etl.CalidadMetricas (idEjecucion, etapa, metrica, valor)
        SELECT @id, 'DESPUES', v.metrica, v.valor
        FROM s
        CROSS APPLY (VALUES
            ('registros',            CAST(s.n AS DECIMAL(18,4))),
            ('R01_nulos_criticos',   CAST(s.a AS DECIMAL(18,4))),
            ('R02_duplicados',       CAST(s.b AS DECIMAL(18,4))),
            ('R03_dni_invalido',     CAST(s.c AS DECIMAL(18,4))),
            ('R04_estado_invalido',  CAST(s.d AS DECIMAL(18,4))),
            ('R05_fecha_invalida',   CAST(s.e AS DECIMAL(18,4))),
            ('R06_duracion_invalida',CAST(s.f AS DECIMAL(18,4))),
            ('R07_costo_invalido',   CAST(s.g AS DECIMAL(18,4))),
            ('pct_filas_validas',    CAST(100.0 * (s.n - s.x) / NULLIF(s.n, 0) AS DECIMAL(18,4)))
        ) v(metrica, valor)
        UNION ALL
        SELECT @id, 'DESPUES', 'pacientes_sin_seudonimizar', COUNT(*)
        FROM dbo.Dim_Paciente
        WHERE dni IS NOT NULL AND (LEN(dni) <> 64 OR dni COLLATE Latin1_General_BIN LIKE '%[^0-9A-F]%')
        UNION ALL
        SELECT @id, 'DESPUES', 'dim_paciente_duplicados', COUNT(dni) - COUNT(DISTINCT dni)
        FROM dbo.Dim_Paciente;

        COMMIT;

        UPDATE etl.EjecucionLog
           SET fin = SYSDATETIME(), estado = 'OK',
               filas_leidas = @leidas, filas_cargadas = @cargadas, filas_rechazadas = @rech,
               mensaje = CONCAT(N'nuevas=', @nuevas, N'; actualizadas=', @actualizadas, N'; sin_cambio=', @sin_cambio)
         WHERE idEjecucion = @id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        UPDATE etl.EjecucionLog
           SET fin = SYSDATETIME(), estado = 'ERROR', filas_leidas = @leidas, mensaje = ERROR_MESSAGE()
         WHERE idEjecucion = @id;
        THROW;
    END CATCH
END;
GO
