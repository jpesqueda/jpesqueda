#!/bin/bash
# ============================================
# Script: upload_image_interactive.sh
# Descripción:
#   Sube una imagen a múltiples hosts listados en hosts.txt
#   Pide usuario contraseña, ruta y nombre de la imagen.
#   Usa expect para scp.
# ============================================

# --- Obtener usuario actual de Linux ---
usuario=$(whoami)
echo "Usuario actual: $usuario"

# --- Pedir información al usuario ---
read -p "Introduce la ruta completa de la imagen: " ruta_imagen
read -p "Introduce el nombre del archivo de la imagen: " nombre_imagen
echo -n "Introduce la contraseña de $usuario: "
read -s contrasena
echo ""

# --- Validaciones ---
full_path="$ruta_imagen/$nombre_imagen"
if [ ! -f "$full_path" ]; then
    echo "❌ Archivo $full_path no existe."
    exit 1
fi

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

# --- Logs ---
log_file="Peskilog.txt"
error_log_file="ErrorLogs.txt"
> "$log_file"
> "$error_log_file"

# --- Función para subir la imagen a un host ---
upload_image() {
    local host="$1"
    echo "🚀 Subiendo $nombre_imagen a $host..."

    expect -c "
        log_user 0
        spawn scp -o StrictHostKeyChecking=no \"$full_path\" \"$usuario@$host:/bootflash/$nombre_imagen\"
        set timeout -1
        expect {
            \"assword:\" {
                send \"$contrasena\r\"
                exp_continue
            }
            eof { exit 0 }
        }
    " >>"$log_file" 2>>"$error_log_file"

    if [ $? -eq 0 ]; then
        echo "$host: ✅ Transferencia completada"
    else
        echo "$host: ❌ Error en la transferencia"
    fi
}

# --- Subir a todos los hosts ---
for host in "${hosts[@]}"; do
    upload_image "$host"
done

echo "🎉 Todas las transferencias finalizadas."
echo "Revisa $log_file y $error_log_file para detalles."
