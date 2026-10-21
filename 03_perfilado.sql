USE ClinicaLevantateLazaro;
GO

-- A) Bases de datos del servidor
SELECT name FROM sys.databases ORDER BY name;

-- B) Columnas de las tablas existentes
SELECT t.name AS tabla, c.column_id AS orden, c.name AS columna,
       ty.name + CASE WHEN ty.name IN ('varchar','nvarchar','char','nchar')
            THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX'
                 ELSE CAST(CASE WHEN ty.name LIKE 'n%' THEN c.max_length/2
                                ELSE c.max_length END AS VARCHAR(10)) END + ')'
            ELSE '' END AS tipo,
       CASE WHEN c.is_nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END AS nulo,
       CASE WHEN c.is_identity = 1 THEN 'IDENTITY' ELSE '' END AS ident
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty  ON ty.user_type_id = c.user_type_id
ORDER BY t.name, c.column_id;

-- C) Filas por tabla
SELECT t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name ORDER BY t.name;

-- D) Estructura de la tabla de staging
SELECT c.column_id, c.name AS columna, ty.name AS tipo, c.max_length
FROM sys.columns c
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.stg_citas')
ORDER BY c.column_id;

-- E) Nulos y valores distintos por columna de stg_citas
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'SELECT ''' + c.name + ''' AS columna, COUNT(*) AS total_filas, '
    + 'SUM(CASE WHEN [' + c.name + '] IS NULL THEN 1 ELSE 0 END) AS nulos, '
    + 'COUNT(DISTINCT [' + c.name + ']) AS valores_distintos FROM dbo.stg_citas UNION ALL '
FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.stg_citas');
SET @sql = LEFT(@sql, LEN(@sql) - 10);
EXEC sp_executesql @sql;

-- F) id_cita duplicados
SELECT id_cita, COUNT(*) AS veces
FROM dbo.stg_citas GROUP BY id_cita HAVING COUNT(*) > 1;
