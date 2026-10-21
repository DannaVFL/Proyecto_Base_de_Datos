USE ClinicaLevantateLazaro;
GO
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

IF OBJECT_ID('etl.EjecucionLog') IS NULL
CREATE TABLE etl.EjecucionLog (
    idEjecucion      INT IDENTITY(1,1) PRIMARY KEY,
    proceso          VARCHAR(100) NOT NULL,
    inicio           DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    fin              DATETIME2    NULL,
    estado           VARCHAR(20)  NOT NULL DEFAULT 'EN_CURSO',
    filas_leidas     INT NULL,
    filas_cargadas   INT NULL,
    filas_rechazadas INT NULL,
    mensaje          NVARCHAR(4000) NULL
);

IF OBJECT_ID('etl.Rechazos') IS NULL
CREATE TABLE etl.Rechazos (
    idRechazo    INT IDENTITY(1,1) PRIMARY KEY,
    idEjecucion  INT NOT NULL,
    fila_staging INT NULL,
    id_cita      INT NULL,
    regla        VARCHAR(10) NOT NULL,
    detalle      NVARCHAR(200) NULL,
    fecha        DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

IF OBJECT_ID('etl.CalidadMetricas') IS NULL
CREATE TABLE etl.CalidadMetricas (
    idEjecucion INT NOT NULL,
    etapa       VARCHAR(10) NOT NULL,      -- ANTES | DESPUES
    metrica     VARCHAR(60) NOT NULL,
    valor       DECIMAL(18,4) NULL,
    fecha       DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

IF OBJECT_ID('etl.CitaTrabajo') IS NULL
CREATE TABLE etl.CitaTrabajo (
    row_id          INT IDENTITY(1,1) PRIMARY KEY,
    id_cita         INT NULL,
    fecha_raw       VARCHAR(20) NULL,
    dni_raw         VARCHAR(15) NULL,
    nombre_paciente VARCHAR(100) NULL,
    cod_medico      VARCHAR(10) NULL,
    nombre_medico   VARCHAR(100) NULL,
    especialidad    VARCHAR(50) NULL,
    estado          VARCHAR(20) NULL,
    duracion_raw    VARCHAR(10) NULL,
    costo_raw       VARCHAR(20) NULL,
    fecha           DATE NULL,
    dni             VARCHAR(15) NULL,
    dni_hash        VARCHAR(64) NULL,
    duracion_min    INT NULL,
    costo           DECIMAL(10,2) NULL,
    normalizada     TINYINT NOT NULL DEFAULT 0,
    r01 TINYINT NOT NULL DEFAULT 0,
    r02 TINYINT NOT NULL DEFAULT 0,
    r03 TINYINT NOT NULL DEFAULT 0,
    r04 TINYINT NOT NULL DEFAULT 0,
    r05 TINYINT NOT NULL DEFAULT 0,
    r06 TINYINT NOT NULL DEFAULT 0,
    r07 TINYINT NOT NULL DEFAULT 0,
    es_rechazado    TINYINT NOT NULL DEFAULT 0
);
GO

-- Ampliar dni del DW para guardar el hash SHA-256 (seudonimización)
IF (SELECT CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Dim_Paciente' AND COLUMN_NAME = 'dni') < 64
    ALTER TABLE dbo.Dim_Paciente ALTER COLUMN dni VARCHAR(64) NULL;
GO