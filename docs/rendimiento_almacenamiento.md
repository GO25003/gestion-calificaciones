# Rendimiento y almacenamiento

## Sistema de gestión de notas

### 1. Objetivo

Evaluar el funcionamiento de las consultas académicas,
crear índices y revisar el almacenamiento de PostgreSQL.

Las pruebas se realizaron en una base de datos independiente
llamada gestion_notas_rendimiento, sin modificar la base principal.

### 2. Datos utilizados

Se registraron 15 estudiantes en Matemática II,
grupo GT01, ciclo 2026-01.

Resultados:
- 15 estudiantes matriculados.
- 12 estudiantes con calificaciones.
- 3 estudiantes pendientes.
- 24 calificaciones registradas.
- 8 estudiantes aprobados.
- 4 estudiantes reprobados.
- Promedio general de la asignatura: 6.90.

### 3. Consultas académicas

Se desarrollaron cinco consultas:

1. Notas individuales por evaluación.
2. Promedio ponderado de un estudiante.
3. Promedio general por asignatura y ciclo.
4. Estudiantes reprobados.
5. Historial académico de un estudiante.

También se agregó una consulta general para mostrar
estudiantes aprobados, reprobados y pendientes.

Los resultados se guardaron en la carpeta evidencias/rendimiento.

### 4. Índices

Se crearon tres índices:

- idx_estudiantes_nombre: apellidos y nombres.
- idx_asignaturas_nombre: nombre de asignatura.
- idx_calificaciones_fecha: fecha de registro.

Se utilizó EXPLAIN (ANALYZE, BUFFERS) para revisar
el plan de ejecución de tres consultas.

Resultados con 15 estudiantes:

| Consulta | Plan utilizado | Tiempo |
|---|---|---|
| Estudiantes por apellido | Seq Scan | 0.044 ms |
| Asignaturas por nombre | Seq Scan | 0.013 ms |
| Calificaciones por fecha | Seq Scan | 0.017 ms |

PostgreSQL utilizó Seq Scan porque las tablas tienen
pocos registros y el recorrido completo resulta económico.

Por lo tanto, las pruebas no demuestran una mejora
de velocidad por el uso de índices con este volumen.

### 5. Almacenamiento

Se revisó el tamaño de la base de datos, las tablas
y sus índices mediante las funciones de PostgreSQL.

En la medición inicial, la base de pruebas ocupaba
aproximadamente 8703 kB.

El disco del entorno tenía 32 GB de capacidad,
con aproximadamente 19 GB disponibles y 38% de uso.

Estas cifras corresponden al momento de la medición.

### 6. Mantenimiento

Se ejecutó VACUUM (ANALYZE) en:

- estudiantes
- matriculas
- calificaciones

Se verificó que las tres tablas quedaron con
cero registros muertos y con fechas de mantenimiento.

Se recomienda realizar mantenimiento periódico
y mantener habilitado el autovacuum de PostgreSQL.

### 7. Proyección de crecimiento

Se utilizó una estimación de 500 estudiantes nuevos
por ciclo, cinco matrículas por estudiante y
cuatro calificaciones por matrícula.

| Ciclo acumulado | Estudiantes | Matrículas | Calificaciones |
|---|---:|---:|---:|
| 1 | 500 | 2500 | 10000 |
| 2 | 1000 | 5000 | 20000 |
| 3 | 1500 | 7500 | 30000 |
| 4 | 2000 | 10000 | 40000 |
| 5 | 2500 | 12500 | 50000 |

Los valores son estimaciones y no representan
registros reales almacenados en la base de datos.

### 8. Recomendaciones

- Revisar periódicamente el tamaño de las tablas.
- Ejecutar ANALYZE cuando cambie considerablemente
  la cantidad de registros.
- Mantener activo el autovacuum.
- Revisar los registros de errores de PostgreSQL.
- Generar una alerta cuando el disco alcance 80% de uso.
- Evaluar particionamiento solamente si el volumen
  de datos aumenta considerablemente.

### 9. Conclusión

Las consultas académicas funcionaron correctamente
con los 15 estudiantes registrados.

Se crearon tres índices y se comprobaron sus planes
de ejecución. Debido al tamaño reducido de las tablas,
PostgreSQL prefirió realizar recorridos secuenciales.

También se verificó el almacenamiento y se realizó
mantenimiento con VACUUM y ANALYZE.

La base de pruebas permitió comprobar el funcionamiento
de las consultas sin modificar el esquema original.
