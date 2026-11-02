# Sistema de Gestión de Notas de Estudiantes

## Descripción del proyecto

En este proyecto estamos trabajando en la creación de una base de datos para llevar el control de las notas de los estudiantes de una institución educativa.

La idea es tener toda la información académica organizada en un solo lugar, ya que cuando las notas se llevan de forma manual pueden existir errores, registros repetidos o dificultades para encontrar la información.

Para desarrollar el proyecto estamos utilizando PostgreSQL, donde podemos guardar los datos de estudiantes, docentes, asignaturas, grupos y calificaciones.

También buscamos que se puedan consultar las notas, calcular los promedios y conocer cuáles estudiantes aprobaron o reprobaron sus materias.

Este proyecto lo estamos realizando como parte de la evaluación final de la asignatura Administración de Bases de Datos.

## Objetivo del proyecto

Crear una base de datos que nos permita registrar, organizar y consultar la información académica de los estudiantes, aplicando los conocimientos que hemos aprendido durante el ciclo.

## Qué queremos lograr

- Llevar un registro de los estudiantes y docentes.
- Guardar la información de las carreras y asignaturas.
- Organizar los grupos y ciclos académicos.
- Registrar las matrículas de los estudiantes.
- Ingresar las notas de las evaluaciones.
- Calcular los promedios finales.
- Identificar a los estudiantes aprobados y reprobados.
- Consultar el historial de notas.
- Revisar el funcionamiento y espacio de la base de datos.
- Aprender a realizar respaldos y recuperar información.
- Aplicar medidas de seguridad para proteger los datos.

## Cómo funciona nuestro proyecto

El sistema está pensado para que una institución educativa pueda llevar un mejor control de sus registros académicos.

Por ejemplo, primero se registra al estudiante y la carrera a la que pertenece. Después se pueden registrar las asignaturas, los docentes y los grupos disponibles.

Cuando un estudiante se matricula en un grupo, se pueden registrar las notas que obtiene en las diferentes evaluaciones.

Con esta información podemos calcular su promedio final y determinar si aprobó o reprobó la asignatura.

También podemos consultar las notas de un estudiante y obtener resultados generales de un grupo.

## Organización de la base de datos

Para guardar toda la información se creó una base de datos que contiene 11 tablas.

Cada tabla tiene una función diferente y se relaciona con las demás para mantener los registros organizados.

| Tabla | Para qué sirve |
|---|---|
| carreras | Guardar las carreras disponibles. |
| estudiantes | Registrar los datos de los estudiantes. |
| docentes | Guardar la información de los docentes. |
| asignaturas | Registrar las materias. |
| prerrequisitos_asignatura | Guardar los requisitos de algunas materias. |
| ciclos_academicos | Organizar los ciclos académicos. |
| periodos_calificacion | Registrar los períodos de calificaciones. |
| grupos | Organizar los grupos de las asignaturas. |
| matriculas | Registrar a los estudiantes inscritos. |
| evaluaciones | Guardar las actividades que tienen nota. |
| calificaciones | Registrar las notas de los estudiantes. |

Con estas tablas podemos relacionar la información y evitar que los datos se encuentren desordenados.

## Creación de la base de datos

La base de datos se está desarrollando en PostgreSQL.

Primero se creó la estructura principal, donde se encuentran las tablas y sus relaciones.

Después se comenzaron a realizar pruebas para comprobar que los registros se puedan guardar y consultar correctamente.

El archivo principal del proyecto es `academico_mvp.sql`, que contiene la estructura de la base de datos.

## Consultas y pruebas realizadas

Una parte del proyecto consiste en realizar consultas para obtener información de los estudiantes y sus calificaciones.

Entre las consultas que hemos trabajado se encuentran:

- Ver las notas de un estudiante.
- Calcular el promedio final de una materia.
- Consultar el promedio general de una asignatura.
- Identificar a los estudiantes reprobados.
- Consultar el historial académico.
- Mostrar qué estudiantes están aprobados, reprobados o pendientes de notas.

### Ejemplo de nuestras pruebas

Para comprobar que las consultas funcionaran, utilizamos datos de ejemplo de la asignatura Matemática II, grupo GT01.

| Resultados | Cantidad |
|---|---:|
| Estudiantes registrados | 15 |
| Estudiantes matriculados | 15 |
| Estudiantes con notas | 12 |
| Estudiantes aprobados | 8 |
| Estudiantes reprobados | 4 |
| Estudiantes pendientes | 3 |
| Notas registradas | 24 |

El promedio general que obtuvimos fue de **6.90**.

Con estas pruebas comprobamos que las consultas muestran los resultados esperados y permiten conocer la situación académica de los estudiantes.

## Rendimiento y almacenamiento

También trabajamos en revisar cómo funciona la base de datos cuando realizamos consultas.

Para ello creamos algunos índices y comparamos los resultados antes y después de utilizarlos.

Además, revisamos cuánto espacio ocupa la base de datos y sus tablas.

Realizamos tareas de mantenimiento y una estimación de cómo podría crecer la cantidad de estudiantes, matrículas y notas durante cinco ciclos académicos.

Estas actividades nos ayudan a comprender cómo mantener una base de datos organizada y en buenas condiciones.

## Respaldos y recuperación

Otra parte del proyecto consiste en aprender a realizar copias de seguridad de la base de datos.

Esto es importante porque, si ocurre algún problema, necesitamos contar con una forma de recuperar la información.

Dentro de esta parte se contempla realizar respaldos, comprobar que puedan restaurarse y revisar cómo mantener disponible la información.

## Seguridad de la información

También debemos tomar en cuenta que no todos los usuarios deberían tener los mismos permisos.

Por ejemplo, un administrador puede necesitar acceso a diferentes funciones, mientras que otros usuarios solamente deberían consultar determinada información.

Por esta razón, dentro del proyecto se contempla trabajar con permisos, usuarios y revisiones del funcionamiento de la base de datos.

## Herramientas que utilizamos

| Herramienta | Uso |
|---|---|
| PostgreSQL | Crear y trabajar con la base de datos. |
| pgAdmin 4 | Administrar la base de datos y realizar consultas. |
| SQL | Crear tablas, agregar información y consultar datos. |
| Visual Studio Code | Trabajar con los archivos del proyecto. |
| GitHub | Guardar y compartir los avances del grupo. |
| GitHub Codespaces | Realizar parte del desarrollo y las pruebas. |

## Archivos del proyecto

En este repositorio estamos organizando los archivos que utilizamos durante el desarrollo.

| Archivo o carpeta | Contenido |
|---|---|
| `academico_mvp.sql` | Archivo principal de la base de datos. |
| `sql/` | Consultas y archivos SQL. |
| `pruebas/` | Información utilizada para realizar pruebas. |
| `evidencias/` | Resultados obtenidos durante las pruebas. |
| `docs/` | Documentación de las actividades realizadas. |
| `README.md` | Explicación general del proyecto. |

Conforme avancemos, iremos agregando los demás archivos que correspondan a cada actividad.

## Organización del equipo

Este proyecto lo estamos desarrollando entre cuatro integrantes.

Para organizarnos mejor, dividimos las actividades de la siguiente manera:

| Integrante | Actividades |
|---|---|
| Integrante 1 | Diseño y creación de la base de datos, tablas y relaciones. |
| Integrante 2 | Consultas, índices, rendimiento y almacenamiento. |
| Integrante 3 | Respaldos, restauración y recuperación de información. |
| Integrante 4 | Seguridad, monitoreo, documentación y presentación. |

Cada integrante trabaja en su parte y comparte sus avances en GitHub para que podamos reunir todo en un mismo proyecto.

## Avances del proyecto

Hasta el momento hemos avanzado en la creación de la estructura principal de la base de datos.

También se han realizado consultas académicas, pruebas con estudiantes y calificaciones, creación de índices y revisión del almacenamiento.

Estas actividades fueron comprobadas utilizando una base de datos de prueba para no afectar la información principal.

Todavía estamos en el proceso de integrar las demás actividades del grupo y completar la documentación correspondiente.

## Conclusión

Con este proyecto estamos poniendo en práctica lo que hemos aprendido durante el ciclo en Administración de Bases de Datos.

Nos ha permitido comprender mejor cómo se crea una base de datos, cómo se relacionan las tablas y cómo podemos utilizar consultas para obtener información importante.

También estamos aprendiendo sobre otros aspectos, como el mantenimiento, los respaldos y la seguridad de los datos.

Consideramos que este proyecto nos ayuda a reforzar nuestros conocimientos y a trabajar de manera más organizada como equipo, utilizando herramientas que nos servirán en nuestra formación como futuros desarrolladores de software.
