#!/bin/bash
# ============================================
# Script: upload_image_interactive_v2.sh
# Descripción:
#   Sube imágenes a múltiples hosts usando scp + expect.
#   Pide usuario contraseña, ruta y nombre de imagen(es).
#   Muestra barra de progreso basada en bytes reales.
#   Genera resumen final con errores.
# ============================================

# --- Obtener usuario actual ---
usuario=$(whoami)
echo "Usuario actual: $usuario"

# --- Pedir información al usuario ---
read -p "Introduce la ruta donde están las imágenes: " ruta_imagen
read -p "Introduce los nombres de las imágenes separados por espacio: " -a imagenes
echo -n "Introduce la contraseña de $usuario: "
read -s contrasena
echo ""

# --- Validaciones ---
hosts_file="hosts.txt"
if [ ! -f "$hosts_file" ]; then
    echo "❌ Archivo $hosts_file no existe."
    exit 1
fi
readarray -t hosts < "$hosts_file"
if [ ${#hosts[@]} -eq 0 ]; then
    echo "❌ Archivo $hosts_file está vacío."
    exit 1
fi

log_file="Peskilog.txt"
error_log_file="ErrorLogs.txt"
> "$log_file"
> "$error_log_file"

declare -A resultados
declare -A errores

# --- Barra de progreso basada en bytes ---
progress_bar_real() {
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
        local elapsed=$(( $(date +%s) - start_time ))
        [ $elapsed -eq 0 ] && elapsed=1
        local speed=$(echo "scale=2; $bytes/1024/1024/$elapsed" | bc)
        local remaining=$(( (filesize - bytes)/1024/1024/(speed>0?speed:1) ))
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
    (progress_bar_real "$file" "$host") &
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

# --- Subir a todos los hosts ---
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
    full_path="$ruta_imagen/$img"
    if [ ! -f "$full_path" ]; then
        echo "❌ Archivo $full_path no encontrado, se omite."
        continue
    fi
    echo "-----------------------------------------------"
    echo "Subiendo imagen: $img"
    echo "-----------------------------------------------"
    upload_all_hosts "$full_path"
done

# --- Resumen final ---
echo ""
echo "================= Resumen de transferencias ================="
printf "%-20s %-60s %-6s %-50s\n" "Host" "Imagen" "Estado" "Error"
echo "----------------------------------------------------------------------------------------------------------"
for host in "${hosts[@]}"; do
    for img in "${imagenes[@]}"; do
        estado=${resultados["$host|$img"]}
        [ -z "$estado" ] && estado="❌"
        err_msg=${errores["$host|$img"]}
        printf "%-20s %-60s %-6s %-50s\n" "$host" "$img" "$estado" "$err_msg"
    done
done
echo "=========================================================================================================="
echo "🎉 Todas las transferencias finalizadas. Revisa $log_file y $error_log_file para detalles."
