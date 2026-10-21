DROP TABLE IF EXISTS USUARIO;
DROP TABLE IF EXISTS TRATAMIENTO;
DROP TABLE IF EXISTS DIAGNOSTICO;
DROP TABLE IF EXISTS CITA;
DROP TABLE IF EXISTS HISTORIA_CLINICA;
DROP TABLE IF EXISTS MEDICO;
DROP TABLE IF EXISTS PACIENTE;
DROP TABLE IF EXISTS ESPECIALIDAD;

CREATE TABLE PACIENTE(
    id_paciente INT IDENTITY(1,1) PRIMARY KEY,
    dni CHAR(8) UNIQUE NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1) NOT NULL,
    telefono VARCHAR(15),
    correo VARCHAR(100),
    direccion VARCHAR(200)
);

CREATE TABLE ESPECIALIDAD(
    id_especialidad INT IDENTITY(1,1) PRIMARY KEY,
    nombre_especialidad VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255)
);

CREATE TABLE MEDICO(
    id_medico INT IDENTITY(1,1) PRIMARY KEY,
    cmp VARCHAR(20) UNIQUE NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(15),
    correo VARCHAR(100),
    id_especialidad INT NOT NULL,

    FOREIGN KEY (id_especialidad)
    REFERENCES ESPECIALIDAD(id_especialidad)
);

CREATE TABLE HISTORIA_CLINICA (
    id_historia INT IDENTITY(1,1) PRIMARY KEY, 
    fecha_apertura DATE NOT NULL, 
    observaciones VARCHAR(500), 
    id_paciente INT NOT NULL UNIQUE, 

    CONSTRAINT FK_HISTORIA_PACIENTE 
    FOREIGN KEY (id_paciente) 
    REFERENCES PACIENTE(id_paciente)
);

CREATE TABLE CITA ( 
    id_cita INT IDENTITY(1,1) PRIMARY KEY, 
    fecha DATE NOT NULL, 
    hora TIME NOT NULL, 
    estado VARCHAR(20) NOT NULL, 
    id_paciente INT NOT NULL, 
    id_medico INT NOT NULL, 

    CONSTRAINT FK_CITA_PACIENTE 
    FOREIGN KEY (id_paciente) 
    REFERENCES PACIENTE(id_paciente), 
    CONSTRAINT FK_CITA_MEDICO 
    FOREIGN KEY (id_medico) 
REFERENCES MEDICO(id_medico) );

CREATE TABLE DIAGNOSTICO ( 
    id_diagnostico INT IDENTITY(1,1) PRIMARY KEY, 
    descripcion VARCHAR(255) NOT NULL, 
    fecha_diagnostico DATE NOT NULL, 
    id_historia INT NOT NULL, 
    id_cita INT NOT NULL, 

    CONSTRAINT FK_DIAGNOSTICO_HISTORIA 
    FOREIGN KEY (id_historia) 
    REFERENCES HISTORIA_CLINICA(id_historia), 
    CONSTRAINT FK_DIAGNOSTICO_CITA 
    FOREIGN KEY (id_cita) 
    REFERENCES CITA(id_cita) );

    CREATE TABLE TRATAMIENTO ( 
    id_tratamiento INT IDENTITY(1,1) PRIMARY KEY, 
    descripcion VARCHAR(255) NOT NULL, 
    indicaciones VARCHAR(500), 
    id_diagnostico INT NOT NULL, 

    CONSTRAINT FK_TRATAMIENTO_DIAGNOSTICO 
    FOREIGN KEY (id_diagnostico) 
    REFERENCES DIAGNOSTICO(id_diagnostico) );

    CREATE TABLE USUARIO ( 
    id_usuario INT IDENTITY(1,1) PRIMARY KEY, 
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL, 
    rol VARCHAR(30) NOT NULL, 
    id_medico INT NULL, 
    
    CONSTRAINT FK_USUARIO_MEDICO 
    FOREIGN KEY (id_medico) 
    REFERENCES MEDICO(id_medico) );

    INSERT INTO PACIENTE
(dni,nombres,apellidos,fecha_nacimiento,sexo,telefono,correo,direccion)
VALUES
('74581236','Juan','Perez','2000-05-10','M','987654321','juan@gmail.com','Lima');

INSERT INTO ESPECIALIDAD
(nombre_especialidad,descripcion)
VALUES
('Cardiologia','Especialidad del corazon');

INSERT INTO MEDICO
(cmp,nombres,apellidos,telefono,correo,id_especialidad)
VALUES
('CMP001','Ana','Torres','999888777','ana@clinica.com',1);

SELECT * FROM ESPECIALIDAD;
SELECT * FROM PACIENTE;
SELECT * FROM MEDICO;