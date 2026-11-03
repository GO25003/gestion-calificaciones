# Respaldos automáticos de PostgreSQL 15 (Podman)

Automatización de respaldos para la base de datos `gestion-calificaciones`, que corre en un contenedor de Podman con PostgreSQL 18. Se usa un script `.sh` para hacer el respaldo y `cron` para ejecutarlo todos los días.

## Política

| Aspecto | Definición |
|---|---|
| **Frecuencia** | Respaldo completo diario a las 2:00 a. m., formato Custom (`pg_dump -Fc`) |
| **Retención** | Últimos 7 respaldos; los más antiguos se eliminan automáticamente |
| **Ubicación** | `/backups`, fuera del directorio de datos de PostgreSQL |
| **Autenticación** | Archivo `.pgpass` (Linux) / `pgpass.conf` (Windows), sin contraseñas en los scripts |
| **RPO** | 24 horas |
| **RTO** | 60 minutos |
| **Verificación** | Pruebas periódicas de restauración en una base independiente |

## Archivos

- `backup_gestion_calificaciones.sh`: hace el respaldo, valida que el archivo no esté corrupto y aplica la rotación. Si el respaldo falla, no borra los anteriores.

## Implementación

Todos los comandos se ejecutan dentro del contenedor como `root`.

### 1. Instalar cron

```bash
apt-get update && apt-get install -y cron
```

### 2. Crear la carpeta de respaldos

```bash
mkdir -p /backups
chown postgres:postgres /backups
chmod 700 /backups
```

### 3. Configurar `.pgpass`

```bash
echo "localhost:5432:gestion-calificaciones:postgres:TU_PASSWORD" > /var/lib/postgresql/.pgpass
chown postgres:postgres /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass
```

### 4. Instalar el script

```bash
cp backup_gestion_calificaciones.sh /usr/local/bin/
chmod +x /usr/local/bin/backup_gestion_calificaciones.sh
chown postgres:postgres /usr/local/bin/backup_gestion_calificaciones.sh
```

### 5. Probarlo manualmente

```bash
su postgres -c /usr/local/bin/backup_gestion_calificaciones.sh
ls -lh /backups
cat /backups/backup.log
```

### 6. Programar en cron

```bash
cat > /tmp/cronjob << 'EOF'
CRON_TZ=America/El_Salvador
0 2 * * * /usr/local/bin/backup_gestion_calificaciones.sh
EOF

crontab -u postgres /tmp/cronjob
rm /tmp/cronjob
crontab -u postgres -l
```

Si `CRON_TZ` no funciona, usar `0 8 * * *` (8:00 UTC equivale a las 2:00 a. m. en El Salvador).

### 7. Iniciar el servicio cron

```bash
cron
pgrep cron
```

## Verificación de restauración

Sirve para comprobar la integridad del respaldo y medir el RTO real.

```bash
su postgres
createdb -h localhost -U postgres prueba_restore
time pg_restore -h localhost -U postgres -d prueba_restore /backups/$(ls -1t /backups | grep dump | head -1)
psql -h localhost -U postgres -d prueba_restore -c "\dt"
dropdb -h localhost -U postgres prueba_restore
exit
```

Tiempo de restauración medido: _____ (completar con el resultado de `time`).

## Notas

- Cron no arranca solo al reiniciar el contenedor. Se puede iniciar desde el host con `podman exec -d NOMBRE_CONTENEDOR cron`.
- Para que los respaldos sobrevivan si se elimina el contenedor, montar un volumen al crearlo: `-v /ruta/host/backups:/backups:Z`.
- No subir el `.pgpass` real al repositorio.
