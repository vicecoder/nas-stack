# Samba (crazymax/samba) – RPi5 · Debian 12

## Objetivo
Compartir `media`, `downloads` y `datos` por SMB (puerto 445), sin NetBIOS/139. Descubrimiento en Windows vía WSDD2.

## Estado actual
- Imagen: ghcr.io/crazy-max/samba:latest
- Compose: stacks/storage/compose.yml
- Modo red: host
- Usuario SMB: darkvice (definido en /srv/containers/samba/data/config.yml)
- Acceso probado: \\192.168.1.10\media, \downloads, \datos

## Puertos
- 445/TCP (SMB)
- 3702/UDP (WSDD2)

## Volúmenes (host → contenedor)
- /srv/containers/samba/data → /data
- /DATA_NAS/datos/media → /samba/media
- /srv/containers/transmission/downloads → /samba/downloads
- /DATA_NAS/datos → /samba/datos

## Operación
- Arrancar/actualizar:
  docker compose -f stacks/storage/compose.yml up -d samba
- Estado/puertos:
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -i samba
  sudo ss -tulpn | egrep ':445 |:3702 ' || true
- Logs:
  docker logs -n 120 samba | tail -n +1

## Seguridad
- No subir /srv/containers/samba/data/config.yml (contiene contraseña).
- Restringir acceso en LAN (hosts allow = 192.168.1.0/24 127.0.0.1).
