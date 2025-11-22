#!/bin/bash

# ============================================================
# CONFIGURACIÓN: MD5 ESPERADOS
# ============================================================
declare -A EXPECTED_MD5=(
    ["Patch1"]="abcde1"
    ["Patch2"]="abcde2"
    ["Patch3"]="abcde3"
    ["Patch4"]="abcde4"
    ["Patch5"]="abcde5"
    ["Patch6"]="abcde6"
)

SHOW_DIR="./"

echo "=== Validación de MD5 de parches (Nexus 9K) ==="
echo

# ============================================================
# PROCESAR ARCHIVOS .SHOW
# ============================================================
for FILE in "$SHOW_DIR"/*.SHOW; do
    [[ ! -f "$FILE" ]] && continue

    HOST=$(basename "$FILE" .SHOW)

    declare -A FOUND_MD5
    ERROR=0

    echo "Host: $HOST"

    # Leer archivo línea por línea
    while read -r LINE; do

        # Buscar coincidencia contra todas las claves del array EXPECTED_MD5
        for PATCH in "${!EXPECTED_MD5[@]}"; do

            # Buscar línea con formato:
            # show file PatchX.rpm md5sum
            if [[ "$LINE" =~ show\ file\ ${PATCH}\.rpm\ md5sum ]]; then
                PATCH_NAME="$PATCH"

                # La siguiente línea contiene el md5 real
                read -r MD5VAL

                # Guardar md5 encontrado
                FOUND_MD5["$PATCH_NAME"]="$MD5VAL"
            fi
        done
    done < "$FILE"

    # ============================================================
    # VALIDAR PARCHES (md5)
    # ============================================================
    for PATCH in "${!EXPECTED_MD5[@]}"; do
        EXPECTED="${EXPECTED_MD5[$PATCH]}"
        FOUND="${FOUND_MD5[$PATCH]}"

        if [[ -z "$FOUND" ]]; then
            echo "  ❌ $PATCH : Not found"
            ERROR=1
            continue
        fi

        if [[ "$EXPECTED" != "$FOUND" ]]; then
            echo "  ❌ $PATCH : Damaged (expected '$EXPECTED' got '$FOUND')"
            ERROR=1
        fi
    done

    # ============================================================
    # RESULTADO FINAL
    # ============================================================
    if [[ $ERROR -eq 0 ]]; then
        echo "  ✅ All patches validated"
    else
        echo "  ⚠️ Failed patches detected"
    fi

    echo
done
