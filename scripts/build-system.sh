#!/usr/bin/env bash
# =============================================================================
# build-system.sh  —  Rebuild NixOS dall'interno del sistema installato
#
# Uso:  bash scripts/build-system.sh [switch|boot|test|dry-run]
# Default: switch
# =============================================================================
set -euo pipefail

ACTION="${1:-switch}"
FLAKE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST="$(hostname)"

case "$ACTION" in
  switch|boot|test|dry-run|dry-activate) ;;
  *) echo "[ERROR] Azione non valida: $ACTION"; echo "Usa: switch | boot | test | dry-run"; exit 1 ;;
esac

echo "[INFO] nixos-rebuild $ACTION --flake $FLAKE_DIR#$HOST"
echo "[INFO] (richiede sudo)"
echo

sudo nixos-rebuild "$ACTION" \
  --flake "$FLAKE_DIR#$HOST" \
  --show-trace \
  2>&1 | tee "/tmp/nixos-rebuild-$(date +%F_%H%M%S).log"

echo
echo "[OK]  nixos-rebuild $ACTION completato."
if [[ "$ACTION" == "switch" ]]; then
  echo "[INFO] Generazione attiva: $(readlink /run/current-system | grep -o 'nixos-[^-]*'  || true)"
fi
