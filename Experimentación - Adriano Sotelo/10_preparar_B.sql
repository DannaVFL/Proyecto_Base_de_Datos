-- =====================================================================
-- 10_preparar_B.sql
-- FASE 2 (entorno). Solo en ClinicaLL_B: collation de las columnas de
-- negocio e indices. Es re-ejecutable.
--
-- Por que se cambia la collation de las columnas (y no solo se quita COLLATE):
-- el ETL original compara con COLLATE Latin1_General_CI_AI. Si en B se quitara
-- sin mas, la comparacion pasaria a la collation de la base (p. ej. CI_AS) y
-- variantes con/sin tilde ya no coincidirian, cambiando los datos cargados.
-- Dejando las columnas de negocio en CI_AI se conserva el mismo criterio de
-- igualdad y el join es sargable (usa indice) sin COLLATE en la consulta.
-- =====================================================================
USE ClinicaLL_B;
GO

-- 0) Datos heredados del respaldo: B debe partir con el DW vacio
EXEC etl.usp_ResetDW;
GO

-- 1) Quitar indices si existian (no se puede alterar la collation de una columna indexada)
DROP INDEX IF EXISTS IX_DimPaciente_dni  ON dbo.Dim_Paciente;
DROP INDEX IF EXISTS IX_DimMedico_cod    ON dbo.Dim_Medico;
DROP INDEX IF EXISTS IX_DimEsp_nombre    ON dbo.Dim_Especialidad;
DROP INDEX IF EXISTS IX_DimEstado_estado ON dbo.Dim_EstadoCita;
DROP INDEX IF EXISTS IX_DimTiempo_fecha  ON dbo.Dim_Tiempo;
DROP INDEX IF EXISTS UX_Fact_idcita      ON dbo.Fact_Citas;
GO

-- 2) Misma collation (CI_AI) en dimensiones y en la tabla de trabajo
ALTER TABLE dbo.Dim_Medico       ALTER COLUMN cod_medico  VARCHAR(10) COLLATE Latin1_General_CI_AI NOT NULL;
ALTER TABLE dbo.Dim_Especialidad ALTER COLUMN nombre      VARCHAR(50) COLLATE Latin1_General_CI_AI NOT NULL;
ALTER TABLE dbo.Dim_EstadoCita   ALTER COLUMN estado      VARCHAR(65) COLLATE Latin1_General_CI_AI NOT NULL;
ALTER TABLE etl.CitaTrabajo      ALTER COLUMN cod_medico  VARCHAR(10) COLLATE Latin1_General_CI_AI NULL;
ALTER TABLE etl.CitaTrabajo      ALTER COLUMN especialidad VARCHAR(50) COLLATE Latin1_General_CI_AI NULL;
ALTER TABLE etl.CitaTrabajo      ALTER COLUMN estado      VARCHAR(20) COLLATE Latin1_General_CI_AI NULL;
GO

-- 3) Indices en las claves de negocio
CREATE INDEX IX_DimPaciente_dni  ON dbo.Dim_Paciente(dni)        INCLUDE (id_paciente);
CREATE INDEX IX_DimMedico_cod    ON dbo.Dim_Medico(cod_medico)   INCLUDE (id_medico);
CREATE INDEX IX_DimEsp_nombre    ON dbo.Dim_Especialidad(nombre) INCLUDE (id_especialidad);
CREATE INDEX IX_DimEstado_estado ON dbo.Dim_EstadoCita(estado)   INCLUDE (id_estado);
CREATE INDEX IX_DimTiempo_fecha  ON dbo.Dim_Tiempo(fecha)        INCLUDE (id_tiempo);
CREATE UNIQUE INDEX UX_Fact_idcita ON dbo.Fact_Citas(id_cita);
GO

-- 4) Verificacion (guardar captura como evidencia)
SELECT t.name AS tabla, i.name AS indice, i.type_desc, i.is_unique
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
WHERE i.name IS NOT NULL AND t.name LIKE 'Dim[_]%' OR i.name = 'UX_Fact_idcita'
ORDER BY t.name, i.name;

SELECT t.name AS tabla, c.name AS columna, c.collation_name
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
WHERE c.collation_name IS NOT NULL
  AND ((t.name = 'Dim_Medico'       AND c.name = 'cod_medico')
    OR (t.name = 'Dim_Especialidad' AND c.name = 'nombre')
    OR (t.name = 'Dim_EstadoCita'   AND c.name = 'estado')
    OR (t.name = 'CitaTrabajo'      AND c.name IN ('cod_medico','especialidad','estado')))
ORDER BY t.name, c.name;
GO
