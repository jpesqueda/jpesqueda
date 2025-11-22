#!/bin/bash

# Lista de patches que quieres validar
PATCHES=("n9000-smu1" "n9000-smu2" "n9000-smu3" "n9000-smu4" "n9000-smu5" "n9000-smu6")

# Valores esperados de MD5 (en el mismo orden)
MD5_VALUES=("abcde1" "abcde2" "abcde3" "abcde4" "abcde5" "abcde6")

# Buscamos todos los archivos .SHOW
for FILE in *.SHOW; do
    HOSTNAME=$(basename "$FILE" .SHOW)

    declare -A FOUND_MD5
    declare -A STATUS

    # Inicializa los estados
    for i in "${!PATCHES[@]}"; do
        PATCH="${PATCHES[$i]}"
        FOUND_MD5["$PATCH"]=""
        STATUS["$PATCH"]="NOT FOUND"
    done

    # Leer archivo línea por línea
    while IFS= read -r LINE; do
        for i in "${!PATCHES[@]}"; do
            PATCH="${PATCHES[$i]}"

            # Busca una línea que contenga el patch basado en el nombre del array
            # ejemplo:
            # show file n9000-smu1.rpm md5sum
            if [[ "$LINE" =~ show\ file\ ${PATCH}\.rpm\ md5sum ]]; then
                CURRENT_PATCH="$PATCH"
                continue
            fi

            # Detectar la siguiente línea (el MD5 real)
            if [[ -n "$CURRENT_PATCH" ]]; then
                FOUND_MD5["$CURRENT_PATCH"]="$LINE"
                CURRENT_PATCH=""
            fi
        done

    done < "$FILE"

    # Validación
    ALL_OK=true
    OUTPUT=""

    for i in "${!PATCHES[@]}"; do
        PATCH="${PATCHES[$i]}"
        EXPECTED="${MD5_VALUES[$i]}"
        REAL="${FOUND_MD5[$PATCH]}"

        if [[ -z "$REAL" ]]; then
            STATUS["$PATCH"]="NOT FOUND"
            ALL_OK=false
        elif [[ "$REAL" != "$EXPECTED" ]]; then
            STATUS["$PATCH"]="MD5 MISMATCH"
            ALL_OK=false
        else
            STATUS["$PATCH"]="OK"
        fi
    done

    # OUTPUT FINAL
    if $ALL_OK; then
        echo "$HOSTNAME : ALL PATCHES VALIDATED"
    else
        echo "$HOSTNAME : FAILED PATCHES"
        for i in "${!PATCHES[@]}"; do
            PATCH="${PATCHES[$i]}"
            if [[ "${STATUS[$PATCH]}" != "OK" ]]; then
                echo "  $PATCH : ${STATUS[$PATCH]}"
            fi
        done
    fi

    echo "-------------------------------"

done
