-- Tabla de staging stg_citas (reconstruida a partir de los tipos de la tabla original).
-- Todas las columnas son VARCHAR salvo id_cita: los datos entran tal cual vienen del CSV
-- y el ETL los convierte despues. Reemplazar por el script generado desde SSMS
-- (clic derecho en la tabla > Generar script de tabla como > CREATE) si difiere.
USE ClinicaLevantateLazaro;
GO

IF OBJECT_ID('dbo.stg_citas') IS NULL
CREATE TABLE dbo.stg_citas (
    id_cita         INT          NULL,
    fecha           VARCHAR(20)  NULL,
    dni_paciente    VARCHAR(15)  NULL,
    nombre_paciente VARCHAR(100) NULL,
    cod_medico      VARCHAR(10)  NULL,
    nombre_medico   VARCHAR(100) NULL,
    especialidad    VARCHAR(50)  NULL,
    estado          VARCHAR(20)  NULL,
    duracion_min    VARCHAR(10)  NULL,
    costo           VARCHAR(20)  NULL
);
GO

BULK INSERT dbo.stg_citas
FROM 'C:\ETL\citas.csv'
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001' 
);
