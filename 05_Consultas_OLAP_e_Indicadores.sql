-- Consultas OLAP e indicadores, sobre el modelo dimensional del equipo
-- Solo consultas SELECT: no alteran registros.
USE ClinicaLevantateLazaro;
GO

-- KPI 1: cantidad de citas por año y mes
SELECT t.anio AS Anio, t.mes AS Mes,
       SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
GROUP BY t.anio, t.mes
ORDER BY t.anio, t.mes;
GO

-- KPI 2: total de pacientes registrados en la dimension
SELECT COUNT(*) AS Pacientes_Registrados
FROM dbo.Dim_Paciente;
GO

-- KPI 3: citas por año, mes y especialidad
SELECT t.anio AS Anio, t.mes AS Mes, e.nombre AS Especialidad,
       SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_Especialidad e ON e.idEspecialidad = f.idEspecialidad
GROUP BY t.anio, t.mes, e.nombre
ORDER BY t.anio, t.mes, Total_Citas DESC, Especialidad;
GO

-- KPI 4: citas por año, mes y medico
SELECT t.anio AS Anio, t.mes AS Mes, m.cod_medico AS Codigo_Medico,
       m.nombre AS Medico, SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_Medico m ON m.idMedico = f.idMedico
GROUP BY t.anio, t.mes, m.cod_medico, m.nombre
ORDER BY t.anio, t.mes, Total_Citas DESC, Medico;
GO

-- KPI 5: porcentaje de citas atendidas, por año y mes
SELECT t.anio AS Anio, t.mes AS Mes,
       SUM(f.cantidad_citas) AS Total_Citas,
       SUM(CASE WHEN ec.estado = 'Atendida' THEN f.cantidad_citas ELSE 0 END) AS Atendidas,
       CAST(100.0 * SUM(CASE WHEN ec.estado = 'Atendida' THEN f.cantidad_citas ELSE 0 END)
           / NULLIF(SUM(f.cantidad_citas),0) AS DECIMAL(5,2)) AS Porcentaje_Atendidas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_EstadoCita ec ON ec.idEstadoCita = f.idEstadoCita
GROUP BY t.anio, t.mes
ORDER BY t.anio, t.mes;
GO

-- OLAP Roll-up: detalle por especialidad, subtotal mensual, subtotal anual y total general
SELECT CASE WHEN GROUPING(t.anio)=1 THEN 'TODOS' ELSE CAST(t.anio AS VARCHAR(4)) END AS Anio,
       CASE WHEN GROUPING(t.mes)=1 THEN 'TODOS' ELSE CAST(t.mes AS VARCHAR(2)) END AS Mes,
       CASE WHEN GROUPING(e.nombre)=1 THEN 'TODAS' ELSE e.nombre END AS Especialidad,
       SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_Especialidad e ON e.idEspecialidad = f.idEspecialidad
GROUP BY ROLLUP(t.anio, t.mes, e.nombre)
ORDER BY GROUPING(t.anio), t.anio, GROUPING(t.mes), t.mes,
         GROUPING(e.nombre), e.nombre;
GO

-- OLAP Drill-down: detalle diario dentro de cada mes, por especialidad
SELECT t.anio AS Anio, t.mes AS Mes, t.fecha AS Fecha,
       e.nombre AS Especialidad, SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_Especialidad e ON e.idEspecialidad = f.idEspecialidad
GROUP BY t.anio, t.mes, t.fecha, e.nombre
ORDER BY t.fecha, e.nombre;
GO

-- OLAP Slice & Dice: filtrar año, mes y especialidad
DECLARE @Anio INT = 2026, @Mes INT = 5,
        @Especialidad VARCHAR(50) = 'Cardiología';
SELECT t.fecha AS Fecha, e.nombre AS Especialidad,
       m.nombre AS Medico, ec.estado AS Estado,
       SUM(f.cantidad_citas) AS Total_Citas
FROM dbo.Fact_Citas f
JOIN dbo.Dim_Tiempo t ON t.idTiempo = f.idTiempo
JOIN dbo.Dim_Especialidad e ON e.idEspecialidad = f.idEspecialidad
JOIN dbo.Dim_Medico m ON m.idMedico = f.idMedico
JOIN dbo.Dim_EstadoCita ec ON ec.idEstadoCita = f.idEstadoCita
WHERE t.anio = @Anio AND t.mes = @Mes AND e.nombre = @Especialidad
GROUP BY t.fecha, e.nombre, m.nombre, ec.estado
ORDER BY t.fecha, m.nombre;
GO
