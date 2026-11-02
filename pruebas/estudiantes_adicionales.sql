BEGIN;

SET LOCAL search_path TO academico_mvp, public;

INSERT INTO estudiantes
(carrera_id, carnet, nombres, apellidos)
SELECT c.carrera_id, d.carnet, d.nombres, d.apellidos
FROM carreras c
CROSS JOIN (
    VALUES
    ('AL202603', 'Ana Lucia', 'Hernandez Lopez'),
    ('CM202604', 'Carlos Mauricio', 'Martinez Garcia'),
    ('SP202605', 'Sofia Isabel', 'Perez Ramirez'),
    ('JM202606', 'Jose Manuel', 'Gonzalez Flores'),
    ('DV202607', 'Daniel Alejandro', 'Vasquez Torres'),
    ('LG202608', 'Laura Gabriela', 'Lopez Martinez'),
    ('MR202609', 'Miguel Angel', 'Rivera Hernandez'),
    ('KF202610', 'Karla Fernanda', 'Sanchez Perez'),
    ('ER202611', 'Eduardo Rafael', 'Ramirez Cruz'),
    ('NP202612', 'Natalia Beatriz', 'Castro Gomez'),
    ('FH202613', 'Fernando Antonio', 'Morales Diaz'),
    ('PC202614', 'Paola Andrea', 'Flores Romero'),
    ('RH202615', 'Ricardo Alberto', 'Hernandez Molina')
) AS d(carnet, nombres, apellidos)
WHERE c.codigo = 'IDS'
AND NOT EXISTS (
    SELECT 1
    FROM estudiantes e
    WHERE e.carnet = d.carnet
);

COMMIT;
