USE ClinicaLevantateLazaro;
GO

/* =========================
   LIMPIAR TABLAS
   ========================= */
DELETE FROM dbo.TRATAMIENTO;
DELETE FROM dbo.DIAGNOSTICO;
DELETE FROM dbo.CITA;
DELETE FROM dbo.USUARIO;
DELETE FROM dbo.HISTORIA_CLINICA;
DELETE FROM dbo.MEDICO;
DELETE FROM dbo.PACIENTE;
DELETE FROM dbo.ESPECIALIDAD;
GO

/* =========================
   INSERTAR DATOS LIMPIOS
   ========================= */

DECLARE 
    @idCardiologia INT,
    @idPediatria INT,
    @idMedicinaGeneral INT,
    @idDermatologia INT,
    @idNeurologia INT,

    @idPaciente1 INT,
    @idPaciente2 INT,
    @idPaciente3 INT,
    @idPaciente4 INT,
    @idPaciente5 INT,

    @idMedico1 INT,
    @idMedico2 INT,
    @idMedico3 INT,
    @idMedico4 INT,
    @idMedico5 INT,

    @idHistoria1 INT,
    @idHistoria2 INT,
    @idHistoria3 INT,
    @idHistoria4 INT,
    @idHistoria5 INT,

    @idCita1 INT,
    @idCita2 INT,
    @idCita3 INT,
    @idCita4 INT,
    @idCita5 INT,

    @idDiagnostico1 INT,
    @idDiagnostico2 INT,
    @idDiagnostico3 INT,
    @idDiagnostico4 INT,
    @idDiagnostico5 INT;


/* =========================
   ESPECIALIDAD
   ========================= */
INSERT INTO dbo.ESPECIALIDAD (nombre_especialidad, descripcion)
VALUES ('Cardiología', 'Especialidad encargada del diagnóstico y tratamiento de enfermedades del corazón');
SET @idCardiologia = SCOPE_IDENTITY();

INSERT INTO dbo.ESPECIALIDAD (nombre_especialidad, descripcion)
VALUES ('Pediatría', 'Especialidad dedicada a la atención médica de niños y adolescentes');
SET @idPediatria = SCOPE_IDENTITY();

INSERT INTO dbo.ESPECIALIDAD (nombre_especialidad, descripcion)
VALUES ('Medicina General', 'Atención médica primaria para pacientes con diversas dolencias');
SET @idMedicinaGeneral = SCOPE_IDENTITY();

INSERT INTO dbo.ESPECIALIDAD (nombre_especialidad, descripcion)
VALUES ('Dermatología', 'Especialidad encargada del diagnóstico y tratamiento de enfermedades de la piel');
SET @idDermatologia = SCOPE_IDENTITY();

INSERT INTO dbo.ESPECIALIDAD (nombre_especialidad, descripcion)
VALUES ('Neurología', 'Especialidad relacionada con enfermedades del sistema nervioso');
SET @idNeurologia = SCOPE_IDENTITY();


/* =========================
   PACIENTE
   ========================= */
INSERT INTO dbo.PACIENTE 
(dni, nombres, apellidos, fecha_nacimiento, sexo, telefono, correo, direccion)
VALUES 
('74581236', 'Juan Carlos', 'Pérez Gómez', '1995-04-12', 'M', '987654321', 'juan.perez@gmail.com', 'Av. Los Olivos 123');
SET @idPaciente1 = SCOPE_IDENTITY();

INSERT INTO dbo.PACIENTE 
(dni, nombres, apellidos, fecha_nacimiento, sexo, telefono, correo, direccion)
VALUES 
('75896321', 'María Fernanda', 'Torres Díaz', '1998-09-25', 'F', '956321478', 'maria.torres@gmail.com', 'Jr. Las Flores 456');
SET @idPaciente2 = SCOPE_IDENTITY();

INSERT INTO dbo.PACIENTE 
(dni, nombres, apellidos, fecha_nacimiento, sexo, telefono, correo, direccion)
VALUES 
('70124589', 'Luis Alberto', 'Ramírez Soto', '1987-01-18', 'M', '912345678', 'luis.ramirez@gmail.com', 'Av. Perú 789');
SET @idPaciente3 = SCOPE_IDENTITY();

INSERT INTO dbo.PACIENTE 
(dni, nombres, apellidos, fecha_nacimiento, sexo, telefono, correo, direccion)
VALUES 
('78965412', 'Ana Lucía', 'Vargas Rojas', '2001-06-30', 'F', '965874123', 'ana.vargas@gmail.com', 'Calle San Martín 321');
SET @idPaciente4 = SCOPE_IDENTITY();

INSERT INTO dbo.PACIENTE 
(dni, nombres, apellidos, fecha_nacimiento, sexo, telefono, correo, direccion)
VALUES 
('73698541', 'Carlos Eduardo', 'Mendoza Ruiz', '1979-11-10', 'M', '998877665', 'carlos.mendoza@gmail.com', 'Av. Universitaria 555');
SET @idPaciente5 = SCOPE_IDENTITY();


/* =========================
   MEDICO
   ========================= */
INSERT INTO dbo.MEDICO 
(cmp, nombres, apellidos, telefono, correo, id_especialidad)
VALUES 
('CMP001', 'Ana María', 'Torres Salazar', '987111222', 'ana.torres@clinica.com', @idCardiologia);
SET @idMedico1 = SCOPE_IDENTITY();

INSERT INTO dbo.MEDICO 
(cmp, nombres, apellidos, telefono, correo, id_especialidad)
VALUES 
('CMP002', 'Roberto', 'García Medina', '987222333', 'roberto.garcia@clinica.com', @idPediatria);
SET @idMedico2 = SCOPE_IDENTITY();

INSERT INTO dbo.MEDICO 
(cmp, nombres, apellidos, telefono, correo, id_especialidad)
VALUES 
('CMP003', 'Lucía', 'Fernández Castro', '987333444', 'lucia.fernandez@clinica.com', @idMedicinaGeneral);
SET @idMedico3 = SCOPE_IDENTITY();

INSERT INTO dbo.MEDICO 
(cmp, nombres, apellidos, telefono, correo, id_especialidad)
VALUES 
('CMP004', 'Miguel Ángel', 'Rojas Vega', '987444555', 'miguel.rojas@clinica.com', @idDermatologia);
SET @idMedico4 = SCOPE_IDENTITY();

INSERT INTO dbo.MEDICO 
(cmp, nombres, apellidos, telefono, correo, id_especialidad)
VALUES 
('CMP005', 'Patricia', 'Salazar Núñez', '987555666', 'patricia.salazar@clinica.com', @idNeurologia);
SET @idMedico5 = SCOPE_IDENTITY();


/* =========================
   HISTORIA_CLINICA
   ========================= */
INSERT INTO dbo.HISTORIA_CLINICA 
(fecha_apertura, observaciones, id_paciente)
VALUES 
('2026-05-01', 'Paciente con antecedentes familiares de hipertensión.', @idPaciente1);
SET @idHistoria1 = SCOPE_IDENTITY();

INSERT INTO dbo.HISTORIA_CLINICA 
(fecha_apertura, observaciones, id_paciente)
VALUES 
('2026-05-02', 'Paciente sin antecedentes médicos relevantes.', @idPaciente2);
SET @idHistoria2 = SCOPE_IDENTITY();

INSERT INTO dbo.HISTORIA_CLINICA 
(fecha_apertura, observaciones, id_paciente)
VALUES 
('2026-05-03', 'Paciente con alergia a la penicilina.', @idPaciente3);
SET @idHistoria3 = SCOPE_IDENTITY();

INSERT INTO dbo.HISTORIA_CLINICA 
(fecha_apertura, observaciones, id_paciente)
VALUES 
('2026-05-04', 'Paciente con antecedentes de dermatitis.', @idPaciente4);
SET @idHistoria4 = SCOPE_IDENTITY();

INSERT INTO dbo.HISTORIA_CLINICA 
(fecha_apertura, observaciones, id_paciente)
VALUES 
('2026-05-05', 'Paciente con antecedentes de migraña frecuente.', @idPaciente5);
SET @idHistoria5 = SCOPE_IDENTITY();


/* =========================
   CITA
   ========================= */
INSERT INTO dbo.CITA 
(fecha, hora, estado, id_paciente, id_medico)
VALUES 
('2026-05-10', '09:00:00', 'Atendida', @idPaciente1, @idMedico1);
SET @idCita1 = SCOPE_IDENTITY();

INSERT INTO dbo.CITA 
(fecha, hora, estado, id_paciente, id_medico)
VALUES 
('2026-05-10', '10:00:00', 'Atendida', @idPaciente2, @idMedico2);
SET @idCita2 = SCOPE_IDENTITY();

INSERT INTO dbo.CITA 
(fecha, hora, estado, id_paciente, id_medico)
VALUES 
('2026-05-11', '11:30:00', 'Programada', @idPaciente3, @idMedico3);
SET @idCita3 = SCOPE_IDENTITY();

INSERT INTO dbo.CITA 
(fecha, hora, estado, id_paciente, id_medico)
VALUES 
('2026-05-12', '08:30:00', 'Atendida', @idPaciente4, @idMedico4);
SET @idCita4 = SCOPE_IDENTITY();

INSERT INTO dbo.CITA 
(fecha, hora, estado, id_paciente, id_medico)
VALUES 
('2026-05-13', '15:00:00', 'Cancelada', @idPaciente5, @idMedico5);
SET @idCita5 = SCOPE_IDENTITY();


/* =========================
   DIAGNOSTICO
   ========================= */
INSERT INTO dbo.DIAGNOSTICO 
(descripcion, fecha_diagnostico, id_historia, id_cita)
VALUES 
('Hipertensión arterial leve', '2026-05-10', @idHistoria1, @idCita1);
SET @idDiagnostico1 = SCOPE_IDENTITY();

INSERT INTO dbo.DIAGNOSTICO 
(descripcion, fecha_diagnostico, id_historia, id_cita)
VALUES 
('Gripe común', '2026-05-10', @idHistoria2, @idCita2);
SET @idDiagnostico2 = SCOPE_IDENTITY();

INSERT INTO dbo.DIAGNOSTICO 
(descripcion, fecha_diagnostico, id_historia, id_cita)
VALUES 
('Dolor abdominal en evaluación', '2026-05-11', @idHistoria3, @idCita3);
SET @idDiagnostico3 = SCOPE_IDENTITY();

INSERT INTO dbo.DIAGNOSTICO 
(descripcion, fecha_diagnostico, id_historia, id_cita)
VALUES 
('Dermatitis alérgica', '2026-05-12', @idHistoria4, @idCita4);
SET @idDiagnostico4 = SCOPE_IDENTITY();

INSERT INTO dbo.DIAGNOSTICO 
(descripcion, fecha_diagnostico, id_historia, id_cita)
VALUES 
('Migraña recurrente', '2026-05-13', @idHistoria5, @idCita5);
SET @idDiagnostico5 = SCOPE_IDENTITY();


/* =========================
   TRATAMIENTO
   ========================= */
INSERT INTO dbo.TRATAMIENTO 
(descripcion, indicaciones, id_diagnostico)
VALUES 
('Control de presión arterial', 'Tomar medicamento una vez al día y controlar la presión semanalmente.', @idDiagnostico1),
('Tratamiento para gripe', 'Reposo, hidratación y paracetamol cada 8 horas si presenta fiebre.', @idDiagnostico2),
('Evaluación digestiva', 'Realizar exámenes complementarios y mantener dieta blanda.', @idDiagnostico3),
('Crema dermatológica', 'Aplicar crema en la zona afectada dos veces al día por siete días.', @idDiagnostico4),
('Tratamiento para migraña', 'Evitar estrés, descansar adecuadamente y tomar medicamento indicado por el médico.', @idDiagnostico5);


/* =========================
   USUARIO
   ========================= */
INSERT INTO dbo.USUARIO 
(username, [password], rol, id_medico)
VALUES 
('admin', '123456', 'Administrador', NULL),
('atorres', '123456', 'Medico', @idMedico1),
('rgarcia', '123456', 'Medico', @idMedico2),
('lfernandez', '123456', 'Medico', @idMedico3),
('mrojas', '123456', 'Medico', @idMedico4),
('psalazar', '123456', 'Medico', @idMedico5);
GO