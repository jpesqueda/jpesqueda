#!/bin/bash
# ============================================
# Script: upload_nexus_images_final_v2.sh
# Autor:  Jose Pesqueda
# Descripción:
#   Sube imágenes NXOS a Nexus 9K usando scp + expect.
#   Muestra barra de progreso con porcentaje real, velocidad y tiempo restante.
#   Genera resumen final con errores por host/imagen.
# ============================================

usuario="pepito"
directorio_imagen="/Imagenes/Nexus9k/"
hosts_file="hosts.txt"

log_file="Peskilog.txt"
error_log_file="ErrorLogs.txt"

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

> "$log_file"
> "$error_log_file"

declare -A resultados
declare -A errores

# --- Barra de progreso con velocidad y tiempo restante ---
progress_bar_speed() {
  local file="$1"
  local host="$2"
  local temp="/tmp/transfer_${host}.tmp"
  local filesize=$(stat -c%s "$file")
  local width=40
  local start_time=$(date +%s)

  while [ -f "$temp" ]; do
    local bytes=$(stat -c%s "$temp" 2>/dev/null || echo 0)
    local percent=$(( bytes * 100 / filesize ))
    [ $percent -gt 100 ] && percent=100

    # Velocidad MB/s
    local now=$(date +%s)
    local elapsed=$(( now - start_time ))
    [ $elapsed -eq 0 ] && elapsed=1
    local speed=$(echo "scale=2; $bytes/1024/1024/$elapsed" | bc)

    # Tiempo restante estimado
    local remaining=$(( (filesize - bytes) / 1024 / 1024 / (speed > 0 ? speed : 1) ))
    [ $remaining -lt 0 ] && remaining=0

    local filled=$(( percent * width / 100 ))
    local bar=""
    for ((i=0;i<filled;i++)); do bar+="█"; done
    for ((i=filled;i<width;i++)); do bar+=" "; done

    printf "\r⏳ [%s] %3d%% %5.2f MB/s ETA %ds" "$bar" "$percent" "$speed" "$remaining"
    sleep 0.2
  done
  printf "\r✅ [%-40s] 100%% %5.2f MB/s ETA 0s\n" "████████████████████████████████████████" "$speed"
  rm -f "$temp"
}

# --- Función para subir imagen ---
upload_image() {
  local host="$1"
  local file="$2"
  local file_name=$(basename "$file")
  local temp="/tmp/transfer_${host}.tmp"
  > "$temp"

  echo "🚀 Subiendo $file_name a $host..."

  # Expect scp
  expect -c "
    log_user 0
    spawn scp -o StrictHostKeyChecking=no \"$file\" \"$usuario@$host:/bootflash/$file_name\"
    set timeout -1
    expect {
      \"assword:\" { send \"$contrasena\r\"; exp_continue }
      eof { exit 0 }
    }
  " >>"$log_file" 2>>"$error_log_file" &

  pid=$!
  # Barra de progreso en paralelo
  (progress_bar_speed "$file" "$host") &
  wait $pid

  if [ $? -eq 0 ]; then
    resultados["$host|$file_name"]="✅"
    errores["$host|$file_name"]=""
  else
    resultados["$host|$file_name"]="❌"
    err_msg=$(grep "$file_name" "$error_log_file" | tail -n1)
    errores["$host|$file_name"]="$err_msg"
  fi
}

# --- Subir todas las imágenes a todos los hosts ---
upload_all_hosts() {
  local file="$1"
  declare -a pids=()
  for host in "${hosts[@]}"; do
    upload_image "$host" "$file" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

# --- Proceso principal ---
for img in "${imagenes[@]}"; do
  full_path="${directorio_imagen}${img}"
  echo "-----------------------------------------------"
  echo "Subiendo patch: $img"
  echo "-----------------------------------------------"
  upload_all_hosts "$full_path"
done

# --- Resumen final ---
echo ""
echo "================= Resumen de transferencias ================="
printf "%-20s %-60s %-6s %-50s\n" "Host" "Imagen" "Estado" "Error"
echo "----------------------------------------------------------------------------------------------------------"
for host in "${hosts[@]}"; do
  for imagen in "${imagenes[@]}"; do
    estado=${resultados["$host|$imagen"]}
    [ -z "$estado" ] && estado="❌"
    err_msg=${errores["$host|$imagen"]}
    printf "%-20s %-60s %-6s %-50s\n" "$host" "$imagen" "$estado" "$err_msg"
  done
done
echo "=========================================================================================================="
echo "🎉 Todas las transferencias finalizadas. Revisa $log_file y $error_log_file para detalles."
