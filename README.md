# MINER AI | GPU HOST

MOTD dinámico para hosts GPU con Ubuntu Server y Vast.ai. Muestra el estado real
del servidor y de los servicios en cada inicio de sesión SSH, sin depender de
paneles externos ni de telemetría.

```text
╔════════════════════════════════════════════╗
║             MINER AI | GPU HOST             ║
╚════════════════════════════════════════════╝

  Sistema    : Ubuntu Server 24.04 LTS
  Host       : rentalai4
  Usuario    : dominic

  ─────────── ESTADO DEL SERVIDOR ────────────

  CPU        : 12% (8 núcleos)
  RAM        : 3.2 GiB / 31.2 GiB (10%)
  GPU        : NVIDIA GeForce RTX 4090
  GPU Temp   : 42 °C
  GPU Power  : 78 W / 450 W
  Disco      : 128G libres de 512G (25% usado)
  Uptime     : 3 días, 4 horas, 12 minutos

  ───────────────── SERVICIOS ─────────────────

  Vast.ai    : ● ONLINE
  Docker     : ● ACTIVE
  NVIDIA     : ● DETECTED
```

> Los valores anteriores son un ejemplo. El banner consulta los datos reales al
> iniciar sesión: CPU, RAM, GPU, temperatura, consumo, disco, uptime y estado de
> Vast.ai/Docker/NVIDIA.

---

## Características

- Banner Unicode con colores automáticos (o ASCII con `MINER_MOTD_ASCII=1`).
- Datos en tiempo real: CPU, RAM, GPU, temperatura, potencia, disco y uptime.
- Soporte multi-GPU: muestra el modelo, la temperatura máxima y la potencia total.
- Detecta Vast.ai (`vastai_kaalia`), Docker y NVIDIA de forma tolerante a fallos.
- Si falta `nvidia-smi` o un servicio está caído, el resto del banner se muestra igual.
- Timeouts en las consultas para no bloquear el login.
- Instalador idempotente, con copia de seguridad y desinstalación reversible.
- Sin telemetría y sin llamadas de red durante el inicio de sesión.

---

## Requisitos

- Ubuntu Server 20.04/22.04/24.04 (o una distribución con `update-motd.d`).
- `bash`, `awk`, `coreutils` y `df` (incluidos en Ubuntu).
- Driver NVIDIA y `nvidia-smi` para las líneas de GPU. Son opcionales: sin ellos
  se muestra `N/D` / `NOT FOUND`.
- Permisos de root para instalar.

---

## Instalación desde GitHub

Instalación en una línea:

```bash
curl -fsSL https://raw.githubusercontent.com/todocryptomining-sudo/miner-ai-motd/main/install.sh | sudo bash
```

Si prefieres revisar el instalador antes de ejecutarlo:

```bash
curl -fsSL https://raw.githubusercontent.com/todocryptomining-sudo/miner-ai-motd/main/install.sh -o /tmp/miner-ai-motd-install.sh
less /tmp/miner-ai-motd-install.sh
sudo bash /tmp/miner-ai-motd-install.sh
```

También puedes fijar una versión concreta:

```bash
curl -fsSL https://raw.githubusercontent.com/todocryptomining-sudo/miner-ai-motd/v1.0.0/install.sh | sudo bash
```

Al terminar, el instalador muestra una vista previa. El banner aparecerá en el
siguiente inicio de sesión SSH. Para probarlo en la sesión actual:

```bash
/etc/update-motd.d/00-miner-ai
```

### Instalación local

```bash
git clone https://github.com/todocryptomining-sudo/miner-ai-motd.git
cd miner-ai-motd
sudo ./install.sh
```

Si el archivo perdió el permiso de ejecución al copiarlo desde Windows:

```bash
sudo bash install.sh
```

---

## Opciones del instalador

```text
sudo ./install.sh [opciones]

  --repo OWNER/REPO   Repositorio de GitHub del que descargar el MOTD.
  --ref REF           Rama, tag o commit (por defecto: main).
  --keep-defaults     No desactiva los mensajes estándar de Ubuntu.
  --force             Reemplaza un 00-miner-ai existente que no sea de este
                      instalador (guarda una copia de seguridad).
  --uninstall         Elimina el MOTD y restaura los scripts desactivados.
  -h, --help          Ayuda.
  -V, --version       Versión.
```

Por defecto, el instalador desactiva solo mensajes cosméticos o publicitarios de
Ubuntu:

- `00-header` (bienvenida duplicada)
- `10-help-text` (enlaces de documentación)
- `50-motd-news` (noticias/anuncios)
- `90-updates-available` (recuento de actualizaciones)
- `91-contract-ua-esm-status` (aviso de ESM)

No desactiva avisos importantes como reinicio requerido, fin de soporte (HWE) o
fsck. Si quieres conservar todo el MOTD original de Ubuntu, usa
`--keep-defaults`.

---

## Desinstalación

Desde una copia local:

```bash
sudo ./install.sh --uninstall
```

Desde GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/todocryptomining-sudo/miner-ai-motd/main/install.sh | sudo bash -s -- --uninstall
```

La desinstalación elimina `/etc/update-motd.d/00-miner-ai` y vuelve a dar permiso
de ejecución a los scripts del sistema que el instalador había desactivado.

---

## Qué muestra y de dónde sale

| Línea | Fuente |
|---|---|
| Sistema | `/etc/os-release` (Ubuntu se muestra como `Ubuntu Server <versión> LTS`) |
| Host | `hostname -s` |
| Usuario | `logname` (fallback a `$SUDO_USER`, `$USER`, `id -un`) |
| CPU | `/proc/stat` (muestra de 250 ms) y `nproc` |
| RAM | `/proc/meminfo` (`MemAvailable`, con fallback a free+buffers+cached) |
| GPU | `nvidia-smi --query-gpu=name,temperature.gpu,power.draw,power.limit` |
| Disco | `df -Pk /` |
| Uptime | `/proc/uptime` |
| Vast.ai | `systemctl is-active vastai_kaalia`, nombres de contenedores Docker y `pgrep` |
| Docker | `systemctl is-active docker`, `docker info` o socket de Docker |
| NVIDIA | Resultado de `nvidia-smi`, `/dev/nvidia0` o `/proc/driver/nvidia/version` |

Los colores de CPU/RAM/disco cambian según el porcentaje (verde → amarillo → rojo)
y la temperatura de la GPU cambia a amarillo desde 70 °C y a rojo desde 85 °C.
Cada consulta externa tiene un timeout de 2 segundos.

---

## Personalización

El banner se puede ajustar con variables de entorno:

| Variable | Por defecto | Efecto |
|---|---|---|
| `MINER_MOTD_TITLE` | `MINER AI \| GPU HOST` | Texto del título |
| `MINER_MOTD_WIDTH` | `44` | Ancho interior del marco (34–100) |
| `MINER_MOTD_COLOR` | `auto` | `auto`, `always` o `never` |
| `MINER_MOTD_ASCII` | `0` | `1` usa bordes ASCII (`+`, `-`, `|`) |
| `MINER_MOTD_SYSTEM` | automático | Texto fijo para la línea `Sistema` |
| `MINER_MOTD_DISK_PATH` | `/` | Ruta usada por `df` |

Ejemplo de prueba:

```bash
MINER_MOTD_TITLE="RIG 04 | GPU HOST" \
MINER_MOTD_COLOR=always \
/etc/update-motd.d/00-miner-ai
```

Para fijarlas en todas las sesiones, puedes añadirlas a `/etc/environment` o
editar los valores al inicio de `/etc/update-motd.d/00-miner-ai`.

En el MOTD de PAM la salida puede no ser un TTY, por lo que `auto` puede decidir
no usar color. Si quieres colores garantizados en el login, usa
`MINER_MOTD_COLOR=always`; si quieres texto plano, usa `never`.

---

## Solución de problemas

**No aparece el banner**

1. Comprueba que el archivo es ejecutable:
   ```bash
   ls -l /etc/update-motd.d/00-miner-ai
   ```
2. Ejecútalo manualmente:
   ```bash
   /etc/update-motd.d/00-miner-ai
   ```
3. Abre una sesión SSH nueva (no basta con abrir otra pestaña del mismo shell).
4. Comprueba que PAM está configurado para mostrar el MOTD dinámico:
   ```bash
   grep pam_motd /etc/pam.d/sshd /etc/pam.d/login 2>/dev/null
   ```

**La GPU sale como `N/D` o `No detectada`**

```bash
nvidia-smi
```

Si ese comando falla, el problema es del driver/permisos, no del MOTD. El banner
seguirá mostrando el resto del estado.

**Vast.ai sale como `OFFLINE` pero el host está trabajando**

El detector busca el servicio `vastai_kaalia`, contenedores Docker con
`vast`/`kaalia` en el nombre y procesos con esos nombres. Puedes comprobar el
servicio con:

```bash
systemctl status vastai_kaalia --no-pager
```

**Docker sale como `STOPPED`**

```bash
systemctl status docker --no-pager
```

**No quiero que desactive los mensajes de Ubuntu**

Reinstala con:

```bash
sudo ./install.sh --keep-defaults
```

Después, si quieres recuperar los que ya se habían desactivado, desinstala y
vuelve a instalar con esa opción.

**Quiero verlo sin colores (logs, capturas, terminal sin color)**

```bash
MINER_MOTD_COLOR=never /etc/update-motd.d/00-miner-ai
```

---

## Cómo funciona

- El instalador copia `motd/00-miner-ai` a `/etc/update-motd.d/00-miner-ai`.
- Guarda el estado necesario en `/var/lib/miner-ai-motd/` para poder revertir los
  cambios.
- `pam_motd`/`update-motd` ejecutan los scripts de `/etc/update-motd.d/` al iniciar
  sesión; el script solo lee datos locales y escribe por stdout.
- El script no usa `set -e`: un fallo de `nvidia-smi`, Docker o Vast.ai nunca debe
  impedir que se muestre el banner.
- No escribe en disco, no envía datos y no consulta Internet durante el login.

Archivos que toca el instalador:

```text
/etc/update-motd.d/00-miner-ai          (nuevo)
/etc/update-motd.d/00-header            (chmod -x, reversible)
/etc/update-motd.d/10-help-text         (chmod -x, reversible)
/etc/update-motd.d/50-motd-news         (chmod -x, reversible)
/etc/update-motd.d/90-updates-available (chmod -x, reversible)
/etc/update-motd.d/91-contract-ua-esm-status (chmod -x, reversible)
/var/lib/miner-ai-motd/                 (estado para desinstalar)
```

---

## Desarrollo y pruebas

```bash
# Sintaxis
bash -n install.sh
bash -n motd/00-miner-ai
bash -n tests/smoke.sh

# Pruebas (no requieren GPU)
bash tests/smoke.sh
```

El workflow de GitHub Actions ejecuta ShellCheck, las pruebas de humo y una
instalación/desinstalación real en un runner de Ubuntu.

Si haces un fork, actualiza `DEFAULT_REPO` en `install.sh` y las URLs de este
README con tu usuario/organización. Después:

```bash
gh repo create miner-ai-motd --public --source=. --remote=origin --push
git tag v1.0.0
git push origin v1.0.0
```

---

## Estructura

```text
miner-ai-motd/
├── install.sh
├── motd/
│   └── 00-miner-ai
├── tests/
│   └── smoke.sh
├── .github/workflows/ci.yml
├── .editorconfig
├── .gitattributes
├── .gitignore
├── LICENSE
└── README.md
```

---

## Licencia

MIT. Consulta [LICENSE](LICENSE).
