# README — Snapshots ZFS (DATA\_NAS/datos)

> **Entorno**: Raspberry Pi OS (Debian 12), ZFS pool `DATA_NAS`, dataset `DATA_NAS/datos`.
>
> **Automatización actual**: `systemd` timer que ejecuta `/usr/local/sbin/zfs-auto-snapshot.sh` todos los días alrededor de las **02:00–02:05 (America/Lima)** con retención `KEEP=3` y prefijo `auto-`.

---

## 1) Visión general

* Los snapshots diarios creados automáticamente siguen el patrón:

  * `DATA_NAS/datos@auto-YYYY-MM-DD_HHMM` (ej.: `@auto-2025-09-06_1710`).
* **Sólo** se gestionan (rotan/borran) los snapshots con prefijo `auto-`.
* Snapshots manuales o “etiquetados” (p.ej. `@fix-owners-*`, `@pre-samba-fix-*`) **no** se tocan.
* Servicio/Timer:

  * **Servicio**: `/etc/systemd/system/zfs-auto-snapshot.service`
  * **Timer**: `/etc/systemd/system/zfs-auto-snapshot.timer`
  * **Script**: `/usr/local/sbin/zfs-auto-snapshot.sh`

Comandos útiles de estado:

```bash
# Próxima ejecución del timer
systemctl list-timers zfs-auto-snapshot.timer

# Última corrida y salida del script
journalctl -u zfs-auto-snapshot.service -n 50 --no-pager

# Listar snapshots automáticos
sudo zfs list -t snapshot -o name,creation -s creation -r DATA_NAS | grep '^DATA_NAS/datos@auto-'
```

---

## 2) Restaurar SIN copiar (0 I/O pesado)

### Opción A (recomendada): navegar vía `.zfs/snapshot/` (solo lectura)

**Objetivo**: ver y copiar archivos puntuales desde un snapshot sin clonar ni replicar el dataset.

**Pasos**

```bash
# 1) Hacer visibles los snapshots dentro del dataset
sudo zfs set snapdir=visible DATA_NAS/datos

# 2) Navegar el snapshot (solo lectura)
ls -la /DATA_NAS/datos/.zfs/snapshot/auto-YYYY-MM-DD_HHMM | head

# 3) (Opcional) Leer/copiar un archivo pequeño desde el snapshot
head -n 20 \
 "/DATA_NAS/datos/.zfs/snapshot/auto-YYYY-MM-DD_HHMM/RUTA/archivo.txt" 2>/dev/null || true
# Copiar a la ubicación actual del dataset
cp \
 "/DATA_NAS/datos/.zfs/snapshot/auto-YYYY-MM-DD_HHMM/RUTA/archivo.txt" \
 "/DATA_NAS/datos/RUTA/archivo.txt"

# 4) Ocultar nuevamente el directorio de snapshots (orden visual)
sudo zfs set snapdir=hidden DATA_NAS/datos
```

**Notas**

* No se crean datasets ni se escribe en el snapshot.
* El I/O depende **sólo** de lo que abras o copies.

### Opción B: clon **ligero** y de sólo lectura

**Objetivo**: montar un clon puntual del snapshot, sin duplicar datos (copy‑on‑write), para revisar contenido.

**Pasos**

```bash
# 1) Crear clon de solo-lectura (RO)
sudo zfs clone -o readonly=on \
  DATA_NAS/datos@auto-YYYY-MM-DD_HHMM \
  DATA_NAS/datos_restore_test

# 2) Ver mountpoint del clon
sudo zfs list -o name,mountpoint DATA_NAS/datos_restore_test
# (Normalmente se monta en /DATA_NAS/datos_restore_test)

# 3) Revisar contenido / leer archivos
ls -la /DATA_NAS/datos_restore_test | head
head -n 20 /DATA_NAS/datos_restore_test/RUTA/archivo.txt 2>/dev/null || true

# 4) Eliminar el clon cuando ya no se use
sudo zfs destroy DATA_NAS/datos_restore_test
```

**Notas**

* El clon no ocupa espacio significativo, salvo que se escriba (está en RO para evitarlo).
* Si ZFS indica que el snapshot está “ocupado” al destruirlo, verifica y elimina clones dependientes primero (ver sección **5.2**).

---

## 3) Ajustar la retención (`KEEP`)

El script mantiene **hasta `KEEP` snapshots** con prefijo `auto-`. Para cambiarlo:

```bash
# Cambiar a, por ejemplo, 7 diarios
sudo sed -i 's/^KEEP=.*/KEEP=7/' /usr/local/sbin/zfs-auto-snapshot.sh

# Probar manualmente
sudo systemctl start zfs-auto-snapshot.service

# Revisar el log de la corrida
journalctl -u zfs-auto-snapshot.service -n 50 --no-pager
```

**Consejo**: Puedes combinar políticas (p.ej., diarios/semanales/mensuales) ejecutando *instancias* del servicio con distintos prefijos y timers. Consulta con MIRI para plantillas multi‑retención.

---

## 4) Crear snapshots manuales (buenas prácticas)

* Usa nombres descriptivos y fecha/hora:

  ```bash
  sudo zfs snapshot DATA_NAS/datos@label-YYYYMMDD_HHMM
  ```
* Para **proteger** un snapshot manual de borrados accidentales, aplica un **hold**:

  ```bash
  sudo zfs hold KEEP DATA_NAS/datos@label-YYYYMMDD_HHMM
  # Ver holds
  sudo zfs holds DATA_NAS/datos@label-YYYYMMDD_HHMM
  # Quitar hold (si ya no se necesita)
  sudo zfs release KEEP DATA_NAS/datos@label-YYYYMMDD_HHMM
  ```

---

## 5) Mantenimiento y resolución de problemas

### 5.1 Verificación y logs

```bash
# Próxima ejecución y últimas corridas
systemctl list-timers zfs-auto-snapshot.timer
journalctl -u zfs-auto-snapshot.service -n 100 --no-pager
```

### 5.2 “No se puede destruir snapshot”

* **Causa**: hay **clones** o **holds**.
* **Acción**:

  ```bash
  # Ver clones del dataset (busca datasets con origen en el snapshot)
  sudo zfs list -t all -o name,origin | grep '@NOMBRE_DEL_SNAPSHOT' || true

  # Ver holds
  sudo zfs holds DATA_NAS/datos@NOMBRE_DEL_SNAPSHOT || true

  # Elimina clones dependientes primero, luego el snapshot
  sudo zfs destroy DATA_NAS/datos_restore_test  # (ejemplo)
  sudo zfs destroy DATA_NAS/datos@NOMBRE_DEL_SNAPSHOT
  ```

### 5.3 Performance (copias puntuales)

Para leer/copiar sin impactar tanto:

```bash
ionice -c2 -n7 nice -n 10 \
  cp \
  "/DATA_NAS/datos/.zfs/snapshot/auto-YYYY-MM-DD_HHMM/RUTA/archivo.iso" \
  "/DATA_NAS/datos/RUTA/archivo.iso"
```

---

## 6) Persistencia de logs del sistema

Se configuró journald para logs persistentes y límite de 100 MB:

* Archivo: `/etc/systemd/journald.conf`
* Ajustes aplicados:

  ```ini
  Storage=persistent
  SystemMaxUse=100M
  ```

---

## 7) Versionado de la automatización en tu repo

Guardar las piezas de la automatización en `nas-stack` ayuda a documentar y reproducir.

```bash
# Copiar script y unidades hacia el repo
install -D -m755 /usr/local/sbin/zfs-auto-snapshot.sh \
  ~/docker/nas/ops/zfs-auto-snapshot.sh
sudo install -D -m644 /etc/systemd/system/zfs-auto-snapshot.service \
  ~/docker/nas/ops/systemd/zfs-auto-snapshot.service
sudo install -D -m644 /etc/systemd/system/zfs-auto-snapshot.timer \
  ~/docker/nas/ops/systemd/zfs-auto-snapshot.timer
sudo chown -R darkvice:darkvice ~/docker/nas/ops

# Commit
cd ~/docker/nas
git add ops
git commit -m "ops: ZFS auto snapshots (script + systemd timer, keep=3)"
git push -u origin HEAD
```

---

## 8) Apéndice: estimar tamaño de un envío (dry‑run)

Para planear réplicas sin transferir datos:

```bash
# Estimación de un envío completo del snapshot
sudo zfs send -nPv DATA_NAS/datos@auto-YYYY-MM-DD_HHMM | cat

# Estimación incremental entre dos snapshots
# sudo zfs send -nPv -I DATA_NAS/datos@auto-A DATA_NAS/datos@auto-B | cat
```

---

### Checklist rápido

* [ ] `systemctl list-timers zfs-auto-snapshot.timer` muestra próxima ejecución.
* [ ] `journalctl -u zfs-auto-snapshot.service` sin errores.
* [ ] `zfs list … | grep '^…@auto-'` muestra hasta `KEEP` snapshots.
* [ ] Restauración probada con **Opción A** (`.zfs/snapshot/`).
* [ ] (Opcional) Snapshots manuales importantes con **hold**.

---

**Mantenedor**: Vicente (@vicecoder) · **Asistente**: MIRI (Mi Raspberry Instructor)

