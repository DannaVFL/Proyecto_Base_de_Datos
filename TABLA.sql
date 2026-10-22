-- =============================================
--  CREACIÓN DE BASE DE DATOS
-- =============================================

CREATE DATABASE ClinicaLevantateLazaro

-- =============================================
--  TABLAS DE DIMENSIONES
-- =============================================

CREATE TABLE Dim_Paciente (
    idPaciente INT IDENTITY(1,1) PRIMARY KEY,
    dni VARCHAR(15) NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Medico (
    idMedico INT IDENTITY(1,1) PRIMARY KEY,
    cod_medico VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Especialidad (
    idEspecialidad INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_EstadoCita (
    idEstadoCita INT IDENTITY(1,1) PRIMARY KEY,
    estado VARCHAR(20) NOT NULL
);

CREATE TABLE Dim_Tiempo (
    idTiempo INT IDENTITY(1,1) PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL
);

-- =============================================
-- 2. TABLA DE HECHOS
-- =============================================

CREATE TABLE Fact_Citas (
    idFactCita INT IDENTITY(1,1) PRIMARY KEY,
    id_cita INT NOT NULL,
    idTiempo INT NOT NULL,
    idPaciente INT NOT NULL,
    idMedico INT NOT NULL,
    idEspecialidad INT NOT NULL,
    idEstadoCita INT NOT NULL,
    cantidad_citas INT DEFAULT 1,
    duracion_min INT NULL,
    costo_consulta DECIMAL(10,2) NULL,
    
    -- Restricciones de Clave Foránea
    CONSTRAINT FK_FactCitas_Tiempo FOREIGN KEY (idTiempo) 
        REFERENCES Dim_Tiempo(idTiempo),
    CONSTRAINT FK_FactCitas_Paciente FOREIGN KEY (idPaciente) 
        REFERENCES Dim_Paciente(idPaciente),
    CONSTRAINT FK_FactCitas_Medico FOREIGN KEY (idMedico) 
        REFERENCES Dim_Medico(idMedico),
    CONSTRAINT FK_FactCitas_Especialidad FOREIGN KEY (idEspecialidad) 
        REFERENCES Dim_Especialidad(idEspecialidad),
    CONSTRAINT FK_FactCitas_EstadoCita FOREIGN KEY (idEstadoCita) 
        REFERENCES Dim_EstadoCita(idEstadoCita)
);
GO