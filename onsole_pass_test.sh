#!/usr/bin/env bash
# console_ssh_bruteforce_nxos.sh
# Uso: ./console_ssh_bruteforce_nxos.sh devices.csv posible_pass.txt
# devices.csv formato (header opcional):
# device,terminal_server,TSPort
#
# El script:
#  - pide credenciales del Terminal Server (SSH)
#  - pide usuario del device (login:)
#  - intenta cada password del archivo para cada device
#  - intenta spawn literal: "ssh user:port@host" (como pediste) y si falla,
#    reintenta con la sintaxis estándar: ssh -p port user@host
#  - al encontrar credencial válida ejecuta "show version" en Nexus 9K y extrae
#    versión y número de serie (heurística para NX-OS)
#  - imprime resumen en el formato solicitado

set -euo pipefail

CSV_FILE="${1:-devices.csv}"
PASS_FILE="${2:-posible_pass.txt}"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "ERROR: CSV no encontrado: $CSV_FILE"; exit 1
fi
if [[ ! -f "$PASS_FILE" ]]; then
  echo "ERROR: fichero de passwords no encontrado: $PASS_FILE"; exit 1
fi
if ! command -v expect >/dev/null 2>&1; then
  echo "ERROR: 'expect' no está instalado. Instálalo (ej: sudo apt install expect)"; exit 1
fi

# Pedidos al usuario
read -r -p "Usuario del Terminal Server (SSH): " TS_USER
read -rs -p "Password del Terminal Server: " TS_PASS
echo
read -r -p "Usuario del equipo (login:): " DEV_USER
echo

ATTEMPT_TIMEOUT=18
SLEEP_BETWEEN=0.4

declare -A DEVICE_STATUS
declare -A DEVICE_SN
declare -A DEVICE_VER
declare -A DEVICE_PASS_OK

# try_one_password:
#  args: termhost termport device devuser devpass tsuser tspass timeout
#  salida: markers en stdout que el wrapper captura
try_one_password() {
  local termhost="$1"; local termport="$2"
  local device="$3"; local devuser="$4"; local devpass="$5"
  local tsuser="$6"; local tspass="$7"; local tout="$8"

  expect -c "
    log_user 0
    set timeout $tout

    # 1) Intento literal (tal como pediste): spawn ssh user:port@host
    catch {spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $tsuser:$termport@$termhost} spawn_res

    # Si spawn falló, no abortamos: intentaremos la forma portable más abajo
    # Observa: algunos clientes ssh no aceptan user:port@host; por eso hay fallback.

    # Bloque común para manejo de prompts, lo reutilizaremos:
    proc handle_session {devuser devpass tspass tout} {
      expect {
        -re \"(?i)are you sure you want to continue connecting\" {
          send \"yes\r\"; exp_continue
        }
        -re \"(?i)password:\" {
          send -- \"\$tspass\r\"
        }
        timeout {
          puts \"__TS_ERROR__TIMEOUT\"
          exit 2
        }
        eof {
          puts \"__TS_ERROR__EOF\"
          exit 2
        }
      }

      # ahora estamos dentro del console server -> interactuar con la consola serial
      expect {
        -re \"<CTRL>Z|Press.*CTRL.?Z|\\x1a\" {
          # mandar ENTER tras ver el banner de control si aparece
          send \"\r\"
          exp_continue
        }
        -re \"(?i)login:|(?i)username:\" {
          send -- \"\$devuser\r\"
          exp_continue
        }
        -re \"(?i)password:\" {
          # mandamos la password del device
          send -- \"\$devpass\r\"
          expect {
            -re \"#|>|%|\\$\" {
              # autenticado: pedimos show version y devolvemos la salida
              send -- \"terminal length 0\r\"
              send -- \"show version\r\"
              expect {
                -re \"(?s)(.*)(#|>|%|\\$)\" {
                  set out \$expect_out(1,string)
                  puts \"__SUCCESS__\"
                  puts \"__SHOW_VER_BEGIN__\"
                  puts \$out
                  puts \"__SHOW_VER_END__\"
                  exit 0
                }
                timeout {
                  puts \"__SUCCESS__NOPARSE__\"
                  exit 0
                }
              }
            }
            -re \"(?i)incorrect|(?i)authentication failed|(?i)invalid\" {
              puts \"__BAD_CRED__\"
              exit 1
            }
            timeout {
              puts \"__BAD_CRED_TIMEOUT__\"
              exit 2
            }
            eof {
              puts \"__BAD_CRED_EOF__\"
              exit 2
            }
          }
        }
        timeout {
          puts \"__TS_POSTAUTH_TIMEOUT__\"
          exit 2
        }
        eof {
          puts \"__TS_POSTAUTH_EOF__\"
          exit 2
        }
      }
    }

    # Si el spawn inicial produjo algo (es decir, no fue error inmediato), manejamos la sesión.
    if {[info exists spawn_id]} {
      # llamamos al handler
      handle_session \"$devuser\" \"$devpass\" \"$tspass\" $tout
    } else {
      # Fallback: intentamos la sintaxis portable ssh -p port user@host
      catch {spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $termport $tsuser@$termhost} spawn_res2
      if {[info exists spawn_id]} {
        handle_session \"$devuser\" \"$devpass\" \"$tspass\" $tout
      } else {
        puts \"__TS_SPAWN_FAILED__\"
        exit 2
      }
    }
  "
  return $?
}

# Parse NX-OS show version block: heurísticas
parse_nxos_version_and_serial() {
  local blob="$1"
  local ver sn

  # Versión: buscar 'NXOS: version X' o 'system version:'
  ver="$(printf "%s\n" "$blob" | grep -iEo 'NXOS: version [0-9]+([.][0-9]+)*([(][0-9)]+[)]*)?' | head -n1 || true)"
  if [[ -z "$ver" ]]; then
    ver="$(printf "%s\n" "$blob" | grep -iEo 'system version [0-9]+([.][0-9]+)*' | head -n1 || true)"
  fi
  # limpiar
  ver="$(printf '%s' "$ver" | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
  [[ -z "$ver" ]] && ver="Unknown"

  # Serial: buscar 'system serial number:' o 'chassis serial number' o 'system serial'
  sn="$(printf "%s\n" "$blob" | grep -iE 'serial number|chassis serial|system serial' | head -n3 | tr -s ' ' | sed -E 's/.*[sS]erial[^:]*[: ]*//g' | head -n1 | xargs || true)"
  [[ -z "$sn" ]] && sn="Unknown"

  printf "%s|||%s" "$ver" "$sn"
}

# Iteramos CSV
tail -n +1 "$CSV_FILE" | while IFS=, read -r device termserver tsport || [[ -n "$device" ]]; do
  [[ -z "${device// }" ]] && continue
  if [[ "${device,,}" == "device" ]]; then continue; fi

  echo "==> Probando $device (console: $termserver:$tsport)"
  found=0

  while IFS= read -r pass || [[ -n "$pass" ]]; do
    [[ -z "${pass// }" ]] && continue

    out="$(try_one_password "$termserver" "$tsport" "$device" "$DEV_USER" "$pass" "$TS_USER" "$TS_PASS" "$ATTEMPT_TIMEOUT" 2>&1 || true)"

    if printf "%s" "$out"
