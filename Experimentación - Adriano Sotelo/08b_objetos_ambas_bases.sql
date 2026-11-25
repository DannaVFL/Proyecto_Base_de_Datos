-- =====================================================================
-- 08b_objetos_ambas_bases.sql
-- Punto 4: crea usp_ResetDW, etl.Benchmark y vw_FactPlano en AMBAS bases.
-- Es re-ejecutable. Requiere que ClinicaLL_B ya exista (09_respaldo_restaurar_B.sql)
-- y que el esquema etl exista en las dos.
-- Nota: el arnés (08_utilidades_A.sql) guarda las mediciones de A y B en
-- ClinicaLevantateLazaro.etl.Benchmark; la copia de B queda disponible por si
-- prefieres medir cada base por separado.
-- =====================================================================

-- ===================== BASE A: ClinicaLevantateLazaro =====================
USE ClinicaLevantateLazaro;
GO
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
IF OBJECT_ID('etl.Benchmark') IS NULL
CREATE TABLE etl.Benchmark (
    idRun INT IDENTITY(1,1) PRIMARY KEY, fecha_hora DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    variante CHAR(1) NOT NULL, escenario VARCHAR(20) NOT NULL, filas INT NOT NULL,
    cache VARCHAR(6) NOT NULL, corrida INT NOT NULL, ms DECIMAL(14,3) NULL,
    cpu_ms BIGINT NULL, lecturas_logicas BIGINT NULL, estado VARCHAR(20) NULL,
    leidas INT NULL, cargadas INT NULL, rechazadas INT NULL);
GO
CREATE OR ALTER VIEW dbo.vw_FactPlano
AS
SELECT f.id_cita, t.fecha,
       p.dni        COLLATE Latin1_General_100_BIN2 AS dni,
       p.nombre     COLLATE Latin1_General_100_BIN2 AS paciente,
       m.cod_medico COLLATE Latin1_General_100_BIN2 AS cod_medico,
       m.nombre     COLLATE Latin1_General_100_BIN2 AS medico,
       e.nombre     COLLATE Latin1_General_100_BIN2 AS especialidad,
       s.estado     COLLATE Latin1_General_100_BIN2 AS estado,
       f.cantidad_citas, f.duracion_min, f.costo_consulta
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo       t ON t.id_tiempo       = f.id_tiempo
JOIN dbo.Dim_Paciente     p ON p.id_paciente     = f.id_paciente
JOIN dbo.Dim_Medico       m ON m.id_medico       = f.id_medico
JOIN dbo.Dim_Especialidad e ON e.id_especialidad = f.id_especialidad
JOIN dbo.Dim_EstadoCita   s ON s.id_estado       = f.id_estado;
GO

-- ===================== BASE B: ClinicaLL_B =====================
USE ClinicaLL_B;
GO
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
IF OBJECT_ID('etl.Benchmark') IS NULL
CREATE TABLE etl.Benchmark (
    idRun INT IDENTITY(1,1) PRIMARY KEY, fecha_hora DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    variante CHAR(1) NOT NULL, escenario VARCHAR(20) NOT NULL, filas INT NOT NULL,
    cache VARCHAR(6) NOT NULL, corrida INT NOT NULL, ms DECIMAL(14,3) NULL,
    cpu_ms BIGINT NULL, lecturas_logicas BIGINT NULL, estado VARCHAR(20) NULL,
    leidas INT NULL, cargadas INT NULL, rechazadas INT NULL);
GO
CREATE OR ALTER VIEW dbo.vw_FactPlano
AS
SELECT f.id_cita, t.fecha,
       p.dni        COLLATE Latin1_General_100_BIN2 AS dni,
       p.nombre     COLLATE Latin1_General_100_BIN2 AS paciente,
       m.cod_medico COLLATE Latin1_General_100_BIN2 AS cod_medico,
       m.nombre     COLLATE Latin1_General_100_BIN2 AS medico,
       e.nombre     COLLATE Latin1_General_100_BIN2 AS especialidad,
       s.estado     COLLATE Latin1_General_100_BIN2 AS estado,
       f.cantidad_citas, f.duracion_min, f.costo_consulta
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo       t ON t.id_tiempo       = f.id_tiempo
JOIN dbo.Dim_Paciente     p ON p.id_paciente     = f.id_paciente
JOIN dbo.Dim_Medico       m ON m.id_medico       = f.id_medico
JOIN dbo.Dim_Especialidad e ON e.id_especialidad = f.id_especialidad
JOIN dbo.Dim_EstadoCita   s ON s.id_estado       = f.id_estado;
GO

-- Verificacion: los tres objetos deben existir en las dos bases
SELECT 'A' AS bd, OBJECT_ID('ClinicaLevantateLazaro.etl.usp_ResetDW')  AS usp_ResetDW,
       OBJECT_ID('ClinicaLevantateLazaro.etl.Benchmark')               AS Benchmark,
       OBJECT_ID('ClinicaLevantateLazaro.dbo.vw_FactPlano')            AS vw_FactPlano
UNION ALL
SELECT 'B', OBJECT_ID('ClinicaLL_B.etl.usp_ResetDW'),
       OBJECT_ID('ClinicaLL_B.etl.Benchmark'), OBJECT_ID('ClinicaLL_B.dbo.vw_FactPlano');
GO
