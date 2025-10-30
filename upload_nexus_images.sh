#!/bin/bash
# ============================================
# Script: upload_nexus_images.sh
# Autor:  Jose Pesqueda
# Descripción:
#   Sube múltiples imágenes NXOS a varios Nexus 9K
#   usando scp + expect, ejecutando en paralelo.
#   Ahora permite seleccionar host o imagen específicos
#   y solicita la contraseña interactivamente.
# ============================================

# --- VARIABLES GLOBALES ---
usuario="pepito"
directorio_imagen="/Imagenes/Nexus9k/"
hosts_file="hosts.txt"

# Logs
log_file="Peskilog.txt"
error_log_file="ErrorLogs.txt"

# Lista de imágenes disponibles
imagenes=(
  "nxos.CSCwb76218-n9k_ALL-1.8.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwb63451-n9k_ALL-1.6.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwb13774-n9k_ALL-1.8.8-9.3.9.1ib32_n9008.rpm"
  "nxos.CSCwa91783-n9k_ALL-1.6.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCvz43168-n9k_ALL-1.6.6-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwd53591-n9k_ALL-1.8.8-9.3.9.1ib32_n9000.rpm"
)

# --- PARÁMETROS OPCIONALES ---
host_filtro=""
imagen_filtro=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host_filtro="$2"
      shift 2
      ;;
    --imagen)
      imagen_filtro="$2"
      shift 2
      ;;
    *)
      echo "❌ Opción no reconocida: $1"
      echo "Uso: $0 [--host <nombre>] [--imagen <archivo>]"
      exit 1
      ;;
  esac
done

# --- VALIDACIONES INICIALES ---
if [ ! -f "$hosts_file" ]; then
  echo "❌ El archivo $hosts_file no existe."
  exit 1
fi

readarray -t hosts < "$hosts_file"
if [ ${#hosts[@]} -eq 0 ]; then
  echo "❌ El archivo $hosts_file está vacío."
  exit 1
fi

# Aplicar filtro de host si se especificó
if [ -n "$host_filtro" ]; then
  hosts=("$host_filtro")
fi

# Aplicar filtro de imagen si se especificó
if [ -n "$imagen_filtro" ]; then
  if [[ ! " ${imagenes[*]} " =~ " ${imagen_filtro} " ]]; then
    echo "⚠️  La imagen especificada no está en la lista. Se subirá de todas formas."
  fi
  imagenes=("$imagen_filtro")
fi

# --- SOLICITAR CONTRASEÑA ---
echo -n "🔑 Introduce la contraseña para el usuario $usuario: "
read -s contrasena
echo ""

# Crear/limpiar logs
> "$log_file"
> "$error_log_file"

# --- FUNCIONES ---
upload_image() {
  local host="$1"
  local image_path="$2"
  local image_name
  image_name=$(basename "$image_path")

  echo "🚀 Subiendo $image_name a $host..."

  expect -c "
    log_user 0
    spawn scp -o StrictHostKeyChecking=no \"$image_path\" \"$usuario@$host:/bootflash/$image_name\"
    set timeout -1
    expect {
      \"assword:\" {
        send \"$contrasena\r\"
        exp_continue
      }
      \"100%\" {
        puts \"✅ Completado en $host: $image_name\"
      }
      timeout {
        puts \"❌ Timeout en $host subiendo $image_name\"
        exit 1
      }
      eof
    }
  " >>"$log_file" 2>>"$error_log_file"
}

upload_all_hosts() {
  local image_path="$1"
  declare -a pids=()

  for host in "${hosts[@]}"; do
    upload_image "$host" "$image_path" &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  echo "✅ Todas las transferencias de $(basename "$image_path") se completaron."
}

# --- PROCESO PRINCIPAL ---
for nombre_image in "${imagenes[@]}"; do
  full_path="${directorio_imagen}${nombre_image}"
  echo "-----------------------------------------------"
  echo "Subiendo patch: $nombre_image"
  echo "-----------------------------------------------"
  upload_all_hosts "$full_path"
done

echo "🎉 Todas las imágenes se han subido correctamente."
