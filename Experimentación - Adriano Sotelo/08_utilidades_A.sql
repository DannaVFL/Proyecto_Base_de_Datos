-- =====================================================================
-- 08_utilidades_A.sql
-- FASE 2 (entorno). Ejecutar en la base ORIGINAL (A) ANTES de respaldar
-- y restaurar B, para que B herede estas utilidades.
-- No modifica el ETL original ni crea indices en A.
-- Requisito: dbo.stg_citas debe contener los datos originales del CSV.
-- =====================================================================
USE ClinicaLevantateLazaro;
GO

-- 0) Copia de los datos originales del CSV (para volver al estado inicial)
IF OBJECT_ID('dbo.stg_citas_orig') IS NULL
    SELECT * INTO dbo.stg_citas_orig FROM dbo.stg_citas
    WHERE id_cita IS NULL OR id_cita < 9000;
GO

-- 1) Tabla central de resultados de la medicion (vive en A)
IF OBJECT_ID('etl.Benchmark') IS NULL
CREATE TABLE etl.Benchmark (
    idRun            INT IDENTITY(1,1) PRIMARY KEY,
    fecha_hora       DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    variante         CHAR(1)       NOT NULL,      -- A | B
    escenario        VARCHAR(20)   NOT NULL,      -- E1_inicial | E2_sin_cambios | E3_delta | E4_sucio
    filas            INT           NOT NULL,      -- volumen nominal (filas de pool_base)
    cache            VARCHAR(6)    NOT NULL,      -- tibia | fria
    corrida          INT           NOT NULL,
    ms               DECIMAL(14,3) NULL,
    cpu_ms           BIGINT        NULL,
    lecturas_logicas BIGINT        NULL,
    estado           VARCHAR(20)   NULL,          -- estado en etl.EjecucionLog
    leidas           INT           NULL,
    cargadas         INT           NULL,
    rechazadas       INT           NULL
);
GO

-- 2) Resultados de las pruebas de equivalencia A vs B
IF OBJECT_ID('etl.Equivalencia') IS NULL
CREATE TABLE etl.Equivalencia (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    fecha       DATETIME2   NOT NULL DEFAULT SYSDATETIME(),
    etiqueta    VARCHAR(60) NOT NULL,
    prueba      VARCHAR(40) NOT NULL,
    diferencias INT         NOT NULL,
    resultado   VARCHAR(5)  NOT NULL             -- OK | FALLA
);
GO

-- 3) Reinicio del almacen (deja el DW vacio y con identities en 0)
CREATE OR ALTER PROCEDURE etl.usp_ResetDW
AS
BEGIN
    SET NOCOUNT ON;
    DELETE dbo.Fact_Citas;
    DELETE dbo.Dim_Tiempo;
    DELETE dbo.Dim_Paciente;
    DELETE dbo.Dim_Medico;
    DELETE dbo.Dim_Especialidad;
    DELETE dbo.Dim_EstadoCita;
    DBCC CHECKIDENT ('dbo.Fact_Citas',       RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Dim_Tiempo',       RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Dim_Paciente',     RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Dim_Medico',       RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Dim_Especialidad', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Dim_EstadoCita',   RESEED, 0) WITH NO_INFOMSGS;
    CHECKPOINT;
END;
GO

-- 4) Vista plana del hecho para comparar A y B (sin claves sustitutas).
--    COLLATE BIN2 explicito: comparacion exacta y sin conflictos entre bases.
CREATE OR ALTER VIEW dbo.vw_FactPlano
AS
SELECT f.id_cita,
       t.fecha,
       p.dni            COLLATE Latin1_General_100_BIN2 AS dni,
       p.nombre         COLLATE Latin1_General_100_BIN2 AS paciente,
       m.cod_medico     COLLATE Latin1_General_100_BIN2 AS cod_medico,
       m.nombre         COLLATE Latin1_General_100_BIN2 AS medico,
       e.nombre         COLLATE Latin1_General_100_BIN2 AS especialidad,
       s.estado         COLLATE Latin1_General_100_BIN2 AS estado,
       f.cantidad_citas,
       f.duracion_min,
       f.costo_consulta
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo       t ON t.id_tiempo       = f.id_tiempo
JOIN dbo.Dim_Paciente     p ON p.id_paciente     = f.id_paciente
JOIN dbo.Dim_Medico       m ON m.id_medico       = f.id_medico
JOIN dbo.Dim_Especialidad e ON e.id_especialidad = f.id_especialidad
JOIN dbo.Dim_EstadoCita   s ON s.id_estado       = f.id_estado;
GO

-- 5) Carga de staging desde una version: ORIGINAL | BASE | DELTA | SUCIO
CREATE OR ALTER PROCEDURE etl.usp_CargarStaging
    @version VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF @version NOT IN ('ORIGINAL','BASE','DELTA','SUCIO')
        THROW 50011, 'Version invalida: use ORIGINAL, BASE, DELTA o SUCIO', 1;

    TRUNCATE TABLE dbo.stg_citas;

    IF @version = 'ORIGINAL'
        INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
        SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
        FROM dbo.stg_citas_orig;
    ELSE IF @version = 'BASE'
        INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
        SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
        FROM dbo.pool_base ORDER BY k;
    ELSE IF @version = 'DELTA'
        INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
        SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
        FROM dbo.pool_delta ORDER BY k;
    ELSE
        INSERT INTO dbo.stg_citas (id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo)
        SELECT id_cita, fecha, dni_paciente, nombre_paciente, cod_medico, nombre_medico, especialidad, estado, duracion_min, costo
        FROM dbo.pool_sucio ORDER BY k;
END;
GO

-- 6) Generador de volumen. Crea tres tablas de datos de entrada:
--    pool_base  : N filas validas (10% con estado en minuscula y espacio para ejercitar la limpieza)
--    pool_delta : base con 2% de citas que cambian de estado + 5% de citas nuevas
--    pool_sucio : base con 2% de filas sucias, rotando las reglas R-01..R-07
--    Usa como molde las filas VALIDAS de dbo.stg_plantilla (la crea 12_linea_base_A.sql).
CREATE OR ALTER PROCEDURE etl.usp_GenerarPools
    @filas     INT,
    @pacientes INT = 20000
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.stg_plantilla') IS NULL
        THROW 50010, 'Falta dbo.stg_plantilla: ejecute antes 12_linea_base_A.sql', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.stg_plantilla)
        THROW 50010, 'dbo.stg_plantilla esta vacia: no hay filas validas que usar como molde', 1;

    DROP TABLE IF EXISTS dbo.pool_base, dbo.pool_delta, dbo.pool_sucio;

    CREATE TABLE dbo.pool_delta (
        k INT NOT NULL PRIMARY KEY,
        id_cita INT NULL, fecha VARCHAR(20) NULL, dni_paciente VARCHAR(15) NULL,
        nombre_paciente VARCHAR(100) NULL, cod_medico VARCHAR(10) NULL,
        nombre_medico VARCHAR(100) NULL, especialidad VARCHAR(50) NULL,
        estado VARCHAR(20) NULL, duracion_min VARCHAR(10) NULL, costo VARCHAR(20) NULL);
    SELECT * INTO dbo.pool_base  FROM dbo.pool_delta WHERE 1 = 0;
    SELECT * INTO dbo.pool_sucio FROM dbo.pool_delta WHERE 1 = 0;
    ALTER TABLE dbo.pool_base  ADD CONSTRAINT PK_pool_base  PRIMARY KEY (k);
    ALTER TABLE dbo.pool_sucio ADD CONSTRAINT PK_pool_sucio PRIMARY KEY (k);

    DECLARE @cnt INT = (SELECT COUNT(*) FROM dbo.stg_plantilla);
    DECLARE @m   INT = @filas + CEILING(@filas * 0.05);       -- base + 5% nuevas

    -- a) Todas las filas (base + nuevas) en pool_delta, con estado sin modificar
    ;WITH n AS (
        SELECT TOP (@m) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k
        FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
    )
    INSERT INTO dbo.pool_delta (k, id_cita, fecha, dni_paciente, nombre_paciente, cod_medico,
                                nombre_medico, especialidad, estado, duracion_min, costo)
    SELECT n.k,
           100000 + n.k,
           CONVERT(VARCHAR(20), p.fecha, 23),
           x.dni,
           'PACIENTE ' + x.dni,
           p.cod_medico, p.nombre_medico, p.especialidad,
           CASE WHEN n.k % 10 = 0 THEN LOWER(p.estado) + ' ' ELSE p.estado END,
           CAST(p.duracion_min AS VARCHAR(10)),
           CAST(p.costo AS VARCHAR(20))
    FROM n
    JOIN dbo.stg_plantilla p ON p.rn = (n.k % @cnt) + 1
    CROSS APPLY (SELECT CAST(10000000 + (CAST(n.k AS BIGINT) * 7919 + 13) % @pacientes AS VARCHAR(15)) AS dni) x;

    -- b) pool_base = las primeras @filas
    INSERT INTO dbo.pool_base
    SELECT * FROM dbo.pool_delta WHERE k <= @filas;

    -- c) pool_delta: 2% de la base cambia de estado
    UPDATE dbo.pool_delta
       SET estado = CASE WHEN UPPER(LTRIM(RTRIM(estado))) = 'ATENDIDA' THEN 'CANCELADA' ELSE 'ATENDIDA' END
     WHERE k <= @filas AND k % 50 = 7;

    -- d) pool_sucio: 2% de filas sucias, una regla distinta cada vez (k/50 mod 7)
    INSERT INTO dbo.pool_sucio
    SELECT * FROM dbo.pool_base;

    UPDATE dbo.pool_sucio SET
        dni_paciente = CASE (k / 50) % 7 WHEN 0 THEN NULL            -- R-01 campo obligatorio nulo
                                         WHEN 2 THEN 'ABC-XX'        -- R-03 DNI invalido
                                         ELSE dni_paciente END,
        id_cita      = CASE (k / 50) % 7 WHEN 1 THEN id_cita - 1     -- R-02 id_cita duplicado (el de la fila anterior)
                                         ELSE id_cita END,
        estado       = CASE (k / 50) % 7 WHEN 3 THEN 'Inexistente'   -- R-04 estado fuera de catalogo
                                         ELSE estado END,
        fecha        = CASE (k / 50) % 7 WHEN 4 THEN '2026-13-45'    -- R-05 fecha invalida
                                         ELSE fecha END,
        duracion_min = CASE (k / 50) % 7 WHEN 5 THEN '-30'           -- R-06 duracion invalida
                                         ELSE duracion_min END,
        costo        = CASE (k / 50) % 7 WHEN 6 THEN '-50'           -- R-07 costo invalido
                                         ELSE costo END
    WHERE k % 50 = 0;

    SELECT 'pool_base'  AS tabla, COUNT(*) AS filas FROM dbo.pool_base
    UNION ALL SELECT 'pool_delta', COUNT(*) FROM dbo.pool_delta
    UNION ALL SELECT 'pool_sucio', COUNT(*) FROM dbo.pool_sucio;
END;
GO

-- 7) Copia identica de los pools a B (misma entrada para ambas variantes)
CREATE OR ALTER PROCEDURE etl.usp_CopiarPoolsAB
AS
BEGIN
    SET NOCOUNT ON;
    DROP TABLE IF EXISTS ClinicaLL_B.dbo.pool_base;
    DROP TABLE IF EXISTS ClinicaLL_B.dbo.pool_delta;
    DROP TABLE IF EXISTS ClinicaLL_B.dbo.pool_sucio;
    SELECT * INTO ClinicaLL_B.dbo.pool_base  FROM dbo.pool_base;
    SELECT * INTO ClinicaLL_B.dbo.pool_delta FROM dbo.pool_delta;
    SELECT * INTO ClinicaLL_B.dbo.pool_sucio FROM dbo.pool_sucio;

    SELECT 'A' AS bd, (SELECT COUNT(*) FROM ClinicaLevantateLazaro.dbo.pool_base) AS base,
           (SELECT COUNT(*) FROM ClinicaLevantateLazaro.dbo.pool_delta) AS delta,
           (SELECT COUNT(*) FROM ClinicaLevantateLazaro.dbo.pool_sucio) AS sucio
    UNION ALL
    SELECT 'B', (SELECT COUNT(*) FROM ClinicaLL_B.dbo.pool_base),
           (SELECT COUNT(*) FROM ClinicaLL_B.dbo.pool_delta),
           (SELECT COUNT(*) FROM ClinicaLL_B.dbo.pool_sucio);
END;
GO

-- 8) Prepara el estado inicial de cada escenario (NO se mide). Se ejecuta dentro de cada base.
--    @proc = nombre del procedimiento ETL de esa base (A: etl.usp_EjecutarETL, B: etl.usp_EjecutarETL_B)
CREATE OR ALTER PROCEDURE etl.usp_PrepararEscenario
    @escenario VARCHAR(20),
    @proc      SYSNAME
AS
BEGIN
    SET NOCOUNT ON;
    EXEC etl.usp_ResetDW;

    IF @escenario = 'E1_inicial'            -- DW vacio, staging base
        EXEC etl.usp_CargarStaging 'BASE';
    ELSE IF @escenario = 'E2_sin_cambios'   -- DW poblado, mismo staging
    BEGIN
        EXEC etl.usp_CargarStaging 'BASE';
        EXEC @proc;
    END
    ELSE IF @escenario = 'E3_delta'         -- DW poblado con la base, staging con delta
    BEGIN
        EXEC etl.usp_CargarStaging 'BASE';
        EXEC @proc;
        EXEC etl.usp_CargarStaging 'DELTA';
    END
    ELSE IF @escenario = 'E4_sucio'         -- DW vacio, staging con errores
        EXEC etl.usp_CargarStaging 'SUCIO';
    ELSE
        THROW 50012, 'Escenario invalido', 1;
END;
GO

-- 9) UNA medicion: prepara el escenario, mide el ETL y guarda la fila en etl.Benchmark
CREATE OR ALTER PROCEDURE etl.usp_EjecutarMedicion
    @variante  CHAR(1),          -- 'A' | 'B'
    @escenario VARCHAR(20),
    @corrida   INT,
    @fria      BIT = 0           -- 1 = cache fria (DBCC DROPCLEANBUFFERS; requiere sysadmin; solo servidor de pruebas)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @db   SYSNAME = CASE @variante WHEN 'A' THEN N'ClinicaLevantateLazaro' WHEN 'B' THEN N'ClinicaLL_B' END;
    DECLARE @proc SYSNAME = CASE @variante WHEN 'A' THEN N'etl.usp_EjecutarETL'    WHEN 'B' THEN N'etl.usp_EjecutarETL_B' END;
    IF @db IS NULL THROW 50020, 'Variante invalida (use A o B)', 1;

    DECLARE @sql NVARCHAR(MAX), @filas INT, @t0 DATETIME2(7), @t1 DATETIME2(7),
            @cpu0 BIGINT, @rd0 BIGINT, @cpu1 BIGINT, @rd1 BIGINT,
            @est VARCHAR(20), @le INT, @ca INT, @re INT;

    -- 1) Preparar el escenario (fuera de la medicion)
    SET @sql = N'EXEC ' + QUOTENAME(@db) + N'.etl.usp_PrepararEscenario @escenario = @e, @proc = @p;';
    EXEC sp_executesql @sql, N'@e VARCHAR(20), @p SYSNAME', @e = @escenario, @p = @proc;

    -- 2) Volumen nominal
    SET @sql = N'SELECT @f = COUNT(*) FROM ' + QUOTENAME(@db) + N'.dbo.pool_base;';
    EXEC sp_executesql @sql, N'@f INT OUTPUT', @f = @filas OUTPUT;

    -- 3) Cache fria (opcional)
    IF @fria = 1
    BEGIN
        SET @sql = N'USE ' + QUOTENAME(@db) + N'; CHECKPOINT;';
        EXEC (@sql);
        DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
    END;

    -- 4) Medir
    SELECT @cpu0 = cpu_time, @rd0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    SET @t0 = SYSDATETIME();
    SET @sql = N'EXEC ' + QUOTENAME(@db) + N'.' + @proc + N';';
    EXEC (@sql);
    SET @t1 = SYSDATETIME();
    SELECT @cpu1 = cpu_time, @rd1 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;

    -- 5) Leer el resultado del log de esa base
    SET @sql = N'SELECT TOP 1 @est = estado, @le = filas_leidas, @ca = filas_cargadas, @re = filas_rechazadas FROM '
             + QUOTENAME(@db) + N'.etl.EjecucionLog ORDER BY idEjecucion DESC;';
    EXEC sp_executesql @sql,
         N'@est VARCHAR(20) OUTPUT, @le INT OUTPUT, @ca INT OUTPUT, @re INT OUTPUT',
         @est = @est OUTPUT, @le = @le OUTPUT, @ca = @ca OUTPUT, @re = @re OUTPUT;

    INSERT INTO etl.Benchmark (variante, escenario, filas, cache, corrida, ms, cpu_ms, lecturas_logicas,
                               estado, leidas, cargadas, rechazadas)
    VALUES (@variante, @escenario, @filas, CASE WHEN @fria = 1 THEN 'fria' ELSE 'tibia' END, @corrida,
            DATEDIFF_BIG(MICROSECOND, @t0, @t1) / 1000.0,
            @cpu1 - @cpu0, @rd1 - @rd0, @est, @le, @ca, @re);
END;
GO

-- 10) Comparacion A vs B de la ULTIMA ejecucion de cada base (equivalencia funcional)
CREATE OR ALTER PROCEDURE etl.usp_CompararAB
    @etiqueta VARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @idA INT = (SELECT MAX(idEjecucion) FROM ClinicaLevantateLazaro.etl.EjecucionLog);
    DECLARE @idB INT = (SELECT MAX(idEjecucion) FROM ClinicaLL_B.etl.EjecucionLog);
    DECLARE @n INT;

    -- Hecho: A - B y B - A
    SELECT @n = COUNT(*) FROM (SELECT * FROM ClinicaLevantateLazaro.dbo.vw_FactPlano
                               EXCEPT SELECT * FROM ClinicaLL_B.dbo.vw_FactPlano) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'hecho A-B', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    SELECT @n = COUNT(*) FROM (SELECT * FROM ClinicaLL_B.dbo.vw_FactPlano
                               EXCEPT SELECT * FROM ClinicaLevantateLazaro.dbo.vw_FactPlano) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'hecho B-A', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    -- Hecho: cantidad de filas (EXCEPT no detecta duplicados)
    SELECT @n = ABS((SELECT COUNT(*) FROM ClinicaLevantateLazaro.dbo.Fact_Citas)
                  - (SELECT COUNT(*) FROM ClinicaLL_B.dbo.Fact_Citas));
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'conteo hecho', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    -- Rechazos (id_cita, regla) en ambos sentidos y su cantidad
    SELECT @n = COUNT(*) FROM (SELECT id_cita, regla FROM ClinicaLevantateLazaro.etl.Rechazos WHERE idEjecucion = @idA
                               EXCEPT SELECT id_cita, regla FROM ClinicaLL_B.etl.Rechazos WHERE idEjecucion = @idB) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'rechazos A-B', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    SELECT @n = COUNT(*) FROM (SELECT id_cita, regla FROM ClinicaLL_B.etl.Rechazos WHERE idEjecucion = @idB
                               EXCEPT SELECT id_cita, regla FROM ClinicaLevantateLazaro.etl.Rechazos WHERE idEjecucion = @idA) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'rechazos B-A', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    SELECT @n = ABS((SELECT COUNT(*) FROM ClinicaLevantateLazaro.etl.Rechazos WHERE idEjecucion = @idA)
                  - (SELECT COUNT(*) FROM ClinicaLL_B.etl.Rechazos WHERE idEjecucion = @idB));
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'conteo rechazos', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    -- Metricas de calidad antes/despues en ambos sentidos
    SELECT @n = COUNT(*) FROM (SELECT etapa, metrica, valor FROM ClinicaLevantateLazaro.etl.CalidadMetricas WHERE idEjecucion = @idA
                               EXCEPT SELECT etapa, metrica, valor FROM ClinicaLL_B.etl.CalidadMetricas WHERE idEjecucion = @idB) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'metricas A-B', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    SELECT @n = COUNT(*) FROM (SELECT etapa, metrica, valor FROM ClinicaLL_B.etl.CalidadMetricas WHERE idEjecucion = @idB
                               EXCEPT SELECT etapa, metrica, valor FROM ClinicaLevantateLazaro.etl.CalidadMetricas WHERE idEjecucion = @idA) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'metricas B-A', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    -- Log: estado, leidas, cargadas, rechazadas
    SELECT @n = COUNT(*) FROM (
        SELECT estado, filas_leidas, filas_cargadas, filas_rechazadas FROM ClinicaLevantateLazaro.etl.EjecucionLog WHERE idEjecucion = @idA
        EXCEPT
        SELECT estado, filas_leidas, filas_cargadas, filas_rechazadas FROM ClinicaLL_B.etl.EjecucionLog WHERE idEjecucion = @idB) x;
    INSERT etl.Equivalencia (etiqueta, prueba, diferencias, resultado)
    VALUES (@etiqueta, 'log leidas/cargadas/rech', @n, CASE WHEN @n = 0 THEN 'OK' ELSE 'FALLA' END);

    SELECT etiqueta, prueba, diferencias, resultado
    FROM etl.Equivalencia WHERE etiqueta = @etiqueta ORDER BY id;
END;
GO
