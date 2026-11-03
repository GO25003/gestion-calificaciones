#!/bin/bash
set -uo pipefail

# Cron usa un PATH mínimo, así que lo definimos explícitamente
export PATH=/usr/lib/postgresql/18/bin:/usr/local/bin:/usr/bin:/bin

DB="gestion-calificaciones"
DB_USER="postgres"
DB_HOST="localhost"
BACKUP_DIR="/backups"
RETENCION=7
FECHA=$(date +%Y%m%d_%H%M%S)
ARCHIVO="${BACKUP_DIR}/${DB}_${FECHA}.dump"
LOG="${BACKUP_DIR}/backup.log"

log() { echo "[$(date '+%F %T')] $1" >> "$LOG"; }

log "Iniciando respaldo de ${DB}"

# 1. Respaldo completo en formato Custom
if ! pg_dump -h "$DB_HOST" -U "$DB_USER" -Fc -f "$ARCHIVO" "$DB" 2>> "$LOG"; then
    log "ERROR: falló pg_dump. No se aplica rotación."
    rm -f "$ARCHIVO"
    exit 1
fi

# 2. Verificar que el archivo sea legible
if ! pg_restore -l "$ARCHIVO" > /dev/null 2>> "$LOG"; then
    log "ERROR: el respaldo generado está corrupto."
    rm -f "$ARCHIVO"
    exit 1
fi

log "Respaldo OK: ${ARCHIVO} ($(du -h "$ARCHIVO" | cut -f1))"

# 3. Rotación: conservar solo los últimos N respaldos
ls -1t "${BACKUP_DIR}/${DB}"_*.dump 2>/dev/null | tail -n +$((RETENCION + 1)) | xargs -r rm -f
log "Rotación aplicada (se conservan ${RETENCION})"
