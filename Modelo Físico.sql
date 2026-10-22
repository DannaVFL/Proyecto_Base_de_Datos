USE ClinicaLevantateLazaro;

-- 1. EXTRACCIÓN
TRUNCATE TABLE dbo.stg_citas;

BULK INSERT dbo.stg_citas
FROM 'C:\ETL\Citas.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', CODEPAGE = '65001');

-- 2. TRANSFORMACIÓN
DELETE FROM dbo.stg_citas
WHERE dni_paciente IS NULL OR LTRIM(RTRIM(dni_paciente)) = '' OR fecha IS NULL;

UPDATE dbo.stg_citas SET
  nombre_paciente = UPPER(LTRIM(RTRIM(nombre_paciente))),
  nombre_medico   = UPPER(LTRIM(RTRIM(nombre_medico))),
  especialidad    = UPPER(LTRIM(RTRIM(especialidad))),
  estado          = UPPER(LTRIM(RTRIM(estado)));

;WITH d AS (
  SELECT ROW_NUMBER() OVER (PARTITION BY id_cita ORDER BY id_cita) AS rn FROM dbo.stg_citas
)
DELETE FROM d WHERE rn > 1;

-- 3. CARGA: dimensiones
INSERT INTO dbo.Dim_Paciente (dni, nombre)
SELECT DISTINCT dni_paciente, nombre_paciente FROM dbo.stg_citas s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Paciente d WHERE d.dni = s.dni_paciente);

INSERT INTO dbo.Dim_Medico (cod_medico, nombre)
SELECT DISTINCT cod_medico, nombre_medico FROM dbo.stg_citas s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Medico d WHERE d.cod_medico = s.cod_medico);

INSERT INTO dbo.Dim_Especialidad (nombre)
SELECT DISTINCT especialidad FROM dbo.stg_citas s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Especialidad d WHERE d.nombre = s.especialidad);

INSERT INTO dbo.Dim_EstadoCita (estado)
SELECT DISTINCT estado FROM dbo.stg_citas s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_EstadoCita d WHERE d.estado = s.estado);

INSERT INTO dbo.Dim_Tiempo (fecha, anio, mes, dia)
SELECT DISTINCT CAST(fecha AS DATE), YEAR(CAST(fecha AS DATE)), MONTH(CAST(fecha AS DATE)), DAY(CAST(fecha AS DATE))
FROM dbo.stg_citas s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_Tiempo d WHERE d.fecha = CAST(s.fecha AS DATE));

-- 3. CARGA: hechos
INSERT INTO dbo.Fact_Citas (id_cita, idTiempo, idPaciente, idMedico, idEspecialidad, idEstadoCita,
                            cantidad_citas, duracion_min, costo_consulta)
SELECT s.id_cita, t.idTiempo, p.idPaciente, m.idMedico, e.idEspecialidad, es.idEstadoCita,
       1, CAST(s.duracion_min AS INT), CAST(s.costo AS DECIMAL(10,2))
FROM dbo.stg_citas s
JOIN dbo.Dim_Tiempo t       ON t.fecha = CAST(s.fecha AS DATE)
JOIN dbo.Dim_Paciente p     ON p.dni = s.dni_paciente
JOIN dbo.Dim_Medico m       ON m.cod_medico = s.cod_medico
JOIN dbo.Dim_Especialidad e ON e.nombre = s.especialidad
JOIN dbo.Dim_EstadoCita es  ON es.estado = s.estado
WHERE NOT EXISTS (SELECT 1 FROM dbo.Fact_Citas f WHERE f.id_cita = s.id_cita);

-- 4. VERIFICACIÓN
SELECT COUNT(*) AS stg_citas FROM dbo.stg_citas;
SELECT COUNT(*) AS hechos    FROM dbo.Fact_Citas;

select * from dbo.Fact_Citas;