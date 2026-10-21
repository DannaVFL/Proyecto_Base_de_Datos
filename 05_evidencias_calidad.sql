USE ClinicaLevantateLazaro;
GO

-- Log de ejecuciones
SELECT TOP 10 * FROM etl.EjecucionLog ORDER BY idEjecucion DESC;

-- Reconciliacion: leidas = cargadas + rechazadas
SELECT idEjecucion, filas_leidas, filas_cargadas, filas_rechazadas,
       filas_cargadas + filas_rechazadas AS cargadas_mas_rechazadas
FROM etl.EjecucionLog ORDER BY idEjecucion DESC;

-- Metricas de calidad antes/despues (ultima ejecucion)
SELECT metrica,
       MAX(CASE WHEN etapa = 'ANTES'   THEN valor END) AS antes,
       MAX(CASE WHEN etapa = 'DESPUES' THEN valor END) AS despues
FROM etl.CalidadMetricas
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog)
GROUP BY metrica ORDER BY metrica;

-- Rechazos por regla (ultima ejecucion)
SELECT regla, COUNT(*) AS n FROM etl.Rechazos
WHERE idEjecucion = (SELECT MAX(idEjecucion) FROM etl.EjecucionLog)
GROUP BY regla;

-- Resultado de la seudonimizacion
SELECT TOP 5 * FROM dbo.Dim_Paciente;

-- Filas por tabla
SELECT t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name ORDER BY t.name;
