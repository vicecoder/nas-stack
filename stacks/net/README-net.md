# Net stack – Tailscale + Pi-hole (sin DuckDNS)

## Resumen
- Tailscale: acceso remoto seguro sin puertos abiertos (CGNAT OK).
- Pi-hole: DNS de la LAN (53/TCP+UDP), UI en http://192.168.1.10:5353/admin
- DuckDNS: retirado (era para wg-easy). Reemplazado por Tailscale.

## Archivos
- Compose: stacks/net/compose.yml
- Variables: stacks/net.env (NO subir AuthKey)

## Verificación
- Contenedores:
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | egrep 'tailscale|pihole'
- DNS Tailscale vía Pi-hole:
  nslookup login.tailscale.com 192.168.1.10

## Notas
- Mantener/rotar TS_AUTHKEY en stacks/net.env.
- Pi-hole protegido (password UI) y respaldos en /srv/containers/pihole/.
