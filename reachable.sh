#!/bin/bash

HOSTFILE="host.txt"

# ---------------------------
# Validar archivo
# ---------------------------
if [[ ! -f "$HOSTFILE" ]]; then
    echo "❌ No existe $HOSTFILE"
    exit 1
fi

# ---------------------------
# Cargar hosts en un array
# ---------------------------
mapfile -t HOSTS < "$HOSTFILE"

# Diccionario de estados (0 = no, 1 = sí)
declare -A REACHABLE

for H in "${HOSTS[@]}"; do
    [[ -z "$H" ]] && continue
    REACHABLE["$H"]=0
done

echo "Iniciando monitoreo de reachability..."
echo

# ---------------------------
# Loop hasta que todos estén reachable
# ---------------------------
while true; do
    ALL_OK=1

    for H in "${HOSTS[@]}"; do
        [[ -z "$H" ]] && continue

        # Si ya estaba reachable, saltar
        if [[ ${REACHABLE["$H"]} -eq 1 ]]; then
            continue
        fi

        # Ping rápido
        ping -c 1 -W 1 "$H" > /dev/null 2>&1

        if [[ $? -eq 0 ]]; then
            echo "✔ $H ahora está reachable"
            REACHABLE["$H"]=1
        else
            ALL_OK=0
        fi
    done

    # Si todos están reachables → terminar
    if [[ $ALL_OK -eq 1 ]]; then
        echo
        echo "🎉 Todos los hosts están reachable. Finalizando."
        exit 0
    fi

    # Pequeña pausa antes del siguiente ciclo
    sleep 1
done
