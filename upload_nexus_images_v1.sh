#!/bin/bash
# ============================================
# Script: upload_nexus_images_v1.sh
# Autor:  Jose Pesqueda
# Descripción:
#   Sube múltiples imágenes NXOS a varios Nexus 9K
#   usando scp + expect en paralelo.
#   Muestra una barra de progreso animada.
# ============================================

usuario="pepito"
directorio_imagen="/Imagenes/Nexus9k/"
hosts_file="hosts.txt"

# Logs
log_file="Peskilog.txt"
error_log_file="ErrorLogs.txt"

# Lista de imágenes a subir
imagenes=(
  "nxos.CSCwb76218-n9k_ALL-1.8.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwb63451-n9k_ALL-1.6.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwb13774-n9k_ALL-1.8.8-9.3.9.1ib32_n9008.rpm"
  "nxos.CSCwa91783-n9k_ALL-1.6.8-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCvz43168-n9k_ALL-1.6.6-9.3.9.1ib32_n9000.rpm"
  "nxos.CSCwd53591-n9k_ALL-1.8.8-9.3.9.1ib32_n9000.rpm"
)

# --- Validaciones ---
if [ ! -f "$hosts_file" ]; then
  echo "❌ El archivo $hosts_file no existe."
  exit 1
fi

readarray -t hosts < "$hosts_file"
if [ ${#hosts[@]} -eq 0 ]; then
  echo "❌ El archivo $hosts_file está vacío."
  exit 1
fi

# --- Solicitar contraseña ---
echo -n "🔑 Introduce la contraseña de $usuario: "
read -s contrasena
echo ""

# Limpiar logs anteriores
> "$log_file"
> "$error_log_file"

# --- Función para mostrar barra de progreso animada ---
progress_bar() {
  local pid=$1
  local delay=0.2
  local spin='|/-\'
  local i=0

  echo -n "  "
  while ps -p $pid >/dev/null 2>&1; do
    i=$(( (i+1) %4 ))
    printf "\r⏳ Transfiriendo... ${spin:$i:1}"
    sleep $delay
  done
  printf "\r✅ Transferencia completada!   \n"
}

# --- Función para subir imagen ---
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
      eof {
        exit 0
      }
    }
  " >>"$log_file" 2>>"$error_log_file" &
  
  pid=$!
  progress_bar $pid
  wait $pid
}

# --- Función para subir la imagen a todos los hosts ---
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

  echo "✅ Todas las transferencias de $(basename "$image_path") completadas."
}

# --- Proceso principal ---
for nombre_image in "${imagenes[@]}"; do
  full_path="${directorio_imagen}${nombre_image}"
  echo "-----------------------------------------------"
  echo "Subiendo patch: $nombre_image"
  echo "-----------------------------------------------"
  upload_all_hosts "$full_path"
done

echo "🎉 Todas las imágenes se han subido correctamente."
