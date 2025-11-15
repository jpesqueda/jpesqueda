#!/bin/bash
# -------------------------------------------------------------
# Cisco Nexus 9K Patch Checker -
# -------------------------------------------------------------


OUTPUT_FILE="output_patches.txt"

# ====== PATCHES REQUERIDOS ======
DESIRED_PATCHES=(
  "n9000-dk9.10.2(4e)"
  "n9000-dk9.10.2(4f)"
  "n9000-dk9.10.2(4g)"
  "n9000-dk9.10.2(4h)"
  "n9000-dk9.10.2(4i)"
  "n9000-dk9.10.2(4j)"
)

# ====== FUNCIONES ======

contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# ====== SCRIPT ======

echo "=== Cisco Nexus Patch Validator (Offline Bash) ==="
echo

read -rp "Ingrese el directorio donde están los archivos SHCOM (ej: TMP): " INPUT_DIR
read -rp "Ingrese usuario (solo para registro, no se usa): " USER
read -s -p "Ingrese password (solo para registro, no se usa): " PASS
echo
echo

# Validar directorio
if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ No se encontró el directorio $INPUT_DIR"
  exit 1
fi

# Crear/limpiar archivo salida
> "$OUTPUT_FILE"

# Procesar archivos .SHCOM
for FILE in "$INPUT_DIR"/*.SHCOM; do
  [[ ! -f "$FILE" ]] && continue

  DEVICE=$(basename "$FILE" .SHCOM)   # ejemplo: TMP/Device1.SHCOM -> Device1

  echo "📄 Procesando archivo: $FILE (Device: $DEVICE)"

  # Extraer líneas que contengan algo que parezca un patch
  INSTALLED_PATCHES=($(grep -oE "n[0-9]+[^[:space:]]+" "$FILE" | sort -u))

  echo "   ${#INSTALLED_PATCHES[@]} parches detectados."

  # Comparar con la lista deseada
  MISSING_PATCHES=()
  for PATCH in "${DESIRED_PATCHES[@]}"; do
    contains_element "$PATCH" "${INSTALLED_PATCHES[@]}" || MISSING_PATCHES+=("$PATCH")
  done

  # Escribir salida en archivo
  {
    echo "Device_name:$DEVICE"
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
done

echo "✅ Reporte generado: $OUTPUT_FILE"
