#!/bin/bash
# -------------------------------------------------------------
# Cisco Nexus 9K Patch Checker (Bash version)
# -------------------------------------------------------------
# Autor: ChatGPT
# Descripción:
#   - Se conecta vía SSH a varios Nexus 9K
#   - Ejecuta "show install committed"
#   - Compara con lista de parches definidos en el script
#   - Genera archivo con comandos para instalar/activar los faltantes
# -------------------------------------------------------------

# ====== CONFIGURACIÓN ======
OUTPUT_FILE="output_patches.txt"

# Define aquí los parches requeridos (sin archivo externo)
DESIRED_PATCHES=(
  "n9000-dk9.10.2(4e)"
  "n9000-dk9.10.2(4f)"
  "n9000-dk9.10.2(4g)"
  "n9000-dk9.10.2(4h)"
  "n9000-dk9.10.2(4i)"
  "n9000-dk9.10.2(4j)"
)

# ====== FUNCIONES ======

# Verifica si un elemento existe en un array
contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# ====== SCRIPT PRINCIPAL ======

echo "=== Cisco Nexus Patch Validator (Bash) ==="
echo

read -rp "Ingrese el nombre del archivo de hosts (por ejemplo hosts.txt): " HOSTS_FILE
read -rp "Ingrese el usuario: " USER
read -s -p "Ingrese la contraseña: " PASS
echo
echo

# Validar archivo de hosts
if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "❌ No se encontró el archivo $HOSTS_FILE"
  exit 1
fi

# Limpiar o crear archivo de salida
> "$OUTPUT_FILE"

# Iterar sobre cada host
while IFS= read -r HOST; do
  [[ -z "$HOST" ]] && continue  # saltar líneas vacías
  echo "🔗 Conectando a $HOST ..."

  # Ejecutar comando remoto y capturar salida
  OUTPUT=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$HOST" "show install committed" 2>/dev/null)

  if [[ $? -ne 0 ]]; then
    echo "⚠️  No se pudo conectar a $HOST"
    {
      echo "Device_name:$HOST"
      echo "Error: No se pudo conectar"
      echo
    } >> "$OUTPUT_FILE"
    continue
  fi

  # Extraer líneas que parezcan parches (empiezan con n9000-)
  INSTALLED_PATCHES=($(echo "$OUTPUT" | grep -oE "n[0-9]+-[^[:space:]]+" | sort -u))

  echo "   ${#INSTALLED_PATCHES[@]} parches detectados."

  # Comparar con lista deseada
  MISSING_PATCHES=()
  for PATCH in "${DESIRED_PATCHES[@]}"; do
    contains_element "$PATCH" "${INSTALLED_PATCHES[@]}" || MISSING_PATCHES+=("$PATCH")
  done

  # Escribir resultado
  {
    echo "Device_name:$HOST"
    if [[ ${#MISSING_PATCHES[@]} -eq 0 ]]; then
      echo "Todos los parches están instalados."
      echo
    else
      for PATCH in "${MISSING_PATCHES[@]}"; do
        echo "install add $PATCH"
      done
      echo -n "install activate"
      for PATCH in "${MISSING_PATCHES[@]}"; do
        echo -n " $PATCH"
      done
      echo -e "\n"
    fi
  } >> "$OUTPUT_FILE"

  echo "   Faltantes: ${#MISSING_PATCHES[@]}"
  echo
done < "$HOSTS_FILE"

echo "✅ Resultado guardado en $OUTPUT_FILE"
echo
