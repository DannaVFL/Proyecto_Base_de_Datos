# Databricks notebook source

# EXPERIMENTO 2: BIG DATA
# Evaluación del procesamiento según el volumen de datos

import time
from pyspark.sql import functions as F

# Configuración
volumenes = [10000, 50000, 100000]
particiones = 4
repeticiones = 3

# Calentamiento previo del entorno
spark.range(1000, numPartitions=particiones) \
    .agg(F.sum("id")).collect()

resultados_bigdata = []

for volumen in volumenes:

    tiempos = []

    for repeticion in range(repeticiones):

        inicio = time.perf_counter()

        # Generar registros con configuración constante
        df = spark.range(
            0, volumen, 1, particiones
        )

        # Procesamiento y agregación
        resultado = df.agg(
            F.count("*").alias("total_registros"),
            F.sum("id").alias("suma_ids")
        ).collect()

        fin = time.perf_counter()

        tiempos.append(fin - inicio)

    promedio = sum(tiempos) / repeticiones

    resultados_bigdata.append((
        volumen,
        particiones,
        repeticiones,
        round(promedio, 4)
    ))

# Tabla comparativa
tabla_resultados = spark.createDataFrame(
    resultados_bigdata,
    ["Registros", "Particiones", "Repeticiones", "Tiempo_promedio_segundos"]
)

display(tabla_resultados)


# COMMAND ----------


# EXPERIMENTO 1: BI
# Validación de consistencia de indicadores de citas médicas

from pyspark.sql import functions as F

# 1. Crear datos sintéticos de prueba
datos = [
    (1, "2026-05-10", "Cardiología", "Atendida", 1),
    (2, "2026-05-10", "Pediatría", "Programada", 1),
    (3, "2026-05-11", "Medicina General", "Atendida", 1),
    (4, "2026-05-12", "Dermatología", "Cancelada", 1),
    (5, "2026-05-13", "Neurología", "Atendida", 1)
]

columnas = [
    "id_cita", "fecha", "especialidad",
    "estado", "cantidad_citas"
]

df_citas = spark.createDataFrame(datos, columnas)

# 2. Crear una vista temporal
df_citas.createOrReplaceTempView("citas_medicas")

# 3. Escenario 1: total general
total_general = spark.sql("""
    SELECT SUM(cantidad_citas) AS total_general
    FROM citas_medicas
""")

print("ESCENARIO 1: TOTAL GENERAL")
display(total_general)

# 4. Escenario 2: citas por especialidad
por_especialidad = spark.sql("""
    SELECT especialidad,
           SUM(cantidad_citas) AS total_citas
    FROM citas_medicas
    GROUP BY especialidad
    ORDER BY especialidad
""")

print("ESCENARIO 2: CITAS POR ESPECIALIDAD")
display(por_especialidad)

# 5. Escenario 3: comparar ambos resultados
total_agrupado = (
    por_especialidad
    .agg(F.sum("total_citas").alias("total_agrupado"))
)

comparacion = total_general.crossJoin(total_agrupado)

comparacion = comparacion.withColumn(
    "coinciden",
    F.col("total_general") == F.col("total_agrupado")
)

print("ESCENARIO 3: COMPARACION")
display(comparacion)


# COMMAND ----------


# VALIDACION ADICIONAL DEL EXPERIMENTO BIG DATA
# Cinco repeticiones por volumen de datos

import time
from pyspark.sql import functions as F

volumenes = [10000, 50000, 100000]
particiones = 4
repeticiones = 5

# Calentamiento del entorno
spark.range(1000, numPartitions=particiones) \
    .agg(F.sum("id")).collect()

resultados_repetidos = []

for volumen in volumenes:

    tiempos = []

    for i in range(repeticiones):

        inicio = time.perf_counter()

        df = spark.range(
            0, volumen, 1, particiones
        )

        df.agg(
            F.count("*").alias("total"),
            F.sum("id").alias("suma")
        ).collect()

        fin = time.perf_counter()

        tiempos.append(fin - inicio)

    promedio = sum(tiempos) / len(tiempos)

    resultados_repetidos.append((
        volumen,
        particiones,
        repeticiones,
        round(promedio, 4),
        round(min(tiempos), 4),
        round(max(tiempos), 4)
    ))

tabla_validacion = spark.createDataFrame(
    resultados_repetidos,
    [
        "Registros",
        "Particiones",
        "Repeticiones",
        "Tiempo_promedio",
        "Tiempo_minimo",
        "Tiempo_maximo"
    ]
)

display(tabla_validacion)
