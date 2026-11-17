-- =============================================
--  CREACIÓN DE BASE DE DATOS
-- =============================================

CREATE DATABASE ClinicaLevantateLazaro;

USE ClinicaLevantateLazaro;
Go
-- =============================================
--  TABLAS DE DIMENSIONES
-- =============================================

CREATE TABLE Dim_Paciente (
    id_paciente INT IDENTITY(1,1) PRIMARY KEY,
    dni VARCHAR(65) NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Medico (
    id_medico INT IDENTITY(1,1) PRIMARY KEY,
    cod_medico VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Especialidad (
    id_especialidad INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_EstadoCita (
    id_estado INT IDENTITY(1,1) PRIMARY KEY,
    estado VARCHAR(65) NOT NULL
);

CREATE TABLE Dim_Tiempo (
    id_tiempo INT IDENTITY(1,1) PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL
);

-- =============================================
-- 2. TABLA DE HECHOS
-- =============================================

CREATE TABLE Fact_Citas (
    id_hecho INT IDENTITY(1,1) PRIMARY KEY,
    id_cita INT NOT NULL,
    id_tiempo INT NOT NULL,
    id_paciente INT NOT NULL,
    id_medico INT NOT NULL,
    id_especialidad INT NOT NULL,
    id_estado INT NOT NULL,
    cantidad_citas INT DEFAULT 1,
    duracion_min INT NULL,
    costo_consulta DECIMAL(10,2) NULL,
    
    -- Restricciones de Clave Foránea
    CONSTRAINT FK_FactCitas_Tiempo FOREIGN KEY (id_tiempo) 
        REFERENCES Dim_Tiempo(id_tiempo),
    CONSTRAINT FK_FactCitas_Paciente FOREIGN KEY (id_paciente) 
        REFERENCES Dim_Paciente(id_paciente),
    CONSTRAINT FK_FactCitas_Medico FOREIGN KEY (id_medico) 
        REFERENCES Dim_Medico(id_medico),
    CONSTRAINT FK_FactCitas_Especialidad FOREIGN KEY (id_especialidad) 
        REFERENCES Dim_Especialidad(id_especialidad),
    CONSTRAINT FK_FactCitas_EstadoCita FOREIGN KEY (id_estado) 
        REFERENCES Dim_EstadoCita(id_estado)
);
GO