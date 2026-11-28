Experimentación - Danna Flores
Responsable: Danna Flores

Experimento Big Data (Databricks / Spark)
- Notebook: notebook/04_EXPERIMENTO_PARTICIONAMIENTO.ipynb
- Qué se compara: tabla Delta sin particionar vs particionada por anio y mes (98 033 registros).
- Evidencias: capturas/BD_01 a BD_07.
- Informe: secciones 4.5, 4.6, 6.2, 6.3 y 6.5.

Experimento BI (SQL Server)
- Script: sql/06_EXPERIMENTO_BI_VOLUMEN.sql
- Qué se mide: tiempo de la misma consulta con 960, 10 000 y 100 000 filas (datos sintéticos).
- Evidencias: capturas/BI_01 a BI_08.
- Informe: secciones 4.5, 4.6, 6.2, 6.3 y 6.5.

Cómo reproducir BI
1. Instalar SQL Server y SSMS.
2. Ejecutar los scripts de la carpeta "Proceso ETL - 1000".
3. Cargar citas_1000.csv en dbo.stg_citas con BULK INSERT y ejecutar etl.usp_EjecutarETL.
4. Abrir y ejecutar sql/06_EXPERIMENTO_BI_VOLUMEN.sql.