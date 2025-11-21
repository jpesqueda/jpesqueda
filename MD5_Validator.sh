#!/bin/bash

# ================================
# CONFIGURACIÓN - MD5 esperados
# ================================
declare -A EXPECTED_MD5=(
    ["Patch1"]="abcde1"
    ["Patch2"]="abcde2"
    ["Patch3"]="abcde3"
    ["Patch4"]="abcde4"
    ["Patch5"]="abcde5"
)

SHOW_DIR="./"

echo "=== Validación de MD5 de parches ==="
echo

# ================================
# PROCESAR ARCHIVOS .SHOW
# ================================
for FILE in "$SHOW_DIR"/*.SHOW; do
    [[ ! -f "$FILE" ]] && continue

    HOST=$(basename "$FILE" .SHOW)
    declare -A FOUND_MD5
    ERROR=0

    echo "Host: $HOST"

    # Leer archivo línea por línea
    while read -r LINE; do

        # Detectar línea que contiene el nombre del patch
        if [[ "$LINE" =~ show\ file\ (Patch[0-9]+)\.rpm\ md5sum ]]; then
            PATCH_NAME="${BASH_REMATCH[1]}"
            
            # La siguiente línea contiene el md5
            read -r MD5VAL
            
            # Guardar el valor encontrado
            FOUND_MD5["$PATCH_NAME"]="$MD5VAL"
        fi

    done < "$FILE"

    # ================================
    # Validar parches esperados
    # ================================
    for PATCH in "${!EXPECTED_MD5[@]}"; do
        EXP_VAL="${EXPECTED_MD5[$PATCH]}"
        FOUND_VAL="${FOUND_MD5[$PATCH]}"

        # No existe en el archivo
        if [[ -z "$FOUND_VAL" ]]; then
            echo "  ❌ $PATCH : Not found"
            ERROR=1
            continue
        fi

        # Existe pero es incorrecto
        if [[ "$EXP_VAL" != "$FOUND_VAL" ]]; then
            echo "  ❌ $PATCH : Damaged (expected '$EXP_VAL' got '$FOUND_VAL')"
            ERROR=1
        fi
    done

    # ================================
    # Resultado final
    # ================================
    if [[ $ERROR -eq 0 ]]; then
        echo "  ✅ All patches validated"
    else
        echo "  ⚠️ Failed patches detected"
    fi

    echo
done
