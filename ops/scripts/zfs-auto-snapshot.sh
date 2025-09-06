#!/usr/bin/env bash
set -Eeuo pipefail
DATASET="DATA_NAS/datos"
KEEP=7
PREFIX="auto"
TS="$(date +%F_%H%M)"  # 2025-09-06_0200

SNAP="${DATASET}@${PREFIX}-${TS}"
if zfs list -t snapshot -o name -H | grep -qx "${SNAP}"; then
  echo "INFO: snapshot ya existe: ${SNAP}"
else
  echo "INFO: creando ${SNAP}"
  zfs snapshot "${SNAP}"
fi

mapfile -t AUTO_SNAPS < <(zfs list -H -t snapshot -o name -s creation -r "${DATASET}" \
  | grep -E "^${DATASET}@${PREFIX}-")

COUNT=${#AUTO_SNAPS[@]}
echo "INFO: auto-snapshots detectados: ${COUNT} (keep=${KEEP})"

if (( COUNT > KEEP )); then
  TO_DELETE=("${AUTO_SNAPS[@]:0:COUNT-KEEP}")
  echo "INFO: candidatos a borrar:"; printf '  - %s\n' "${TO_DELETE[@]}"
  for S in "${TO_DELETE[@]}"; do
    if zfs holds -H "$S" 2>/dev/null | grep -q .; then
      echo "WARN: tiene holds, se omite: $S"; continue
    fi
    echo "INFO: destruyendo $S"
    if ! zfs destroy "$S"; then
      echo "ERROR: no se pudo destruir $S (¿clones/holds?)."
    fi
  done
else
  echo "INFO: nada que borrar."
fi
