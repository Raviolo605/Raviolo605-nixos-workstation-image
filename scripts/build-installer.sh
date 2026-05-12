#!/usr/bin/env bash
# =============================================================================
# build-installer.sh  —  Scarica la ISO NixOS minimale ufficiale
#
# Uso:  bash scripts/build-installer.sh [output-dir]
# Default output-dir: ./iso
# =============================================================================
set -euo pipefail

OUT="${1:-$(dirname "$0")/../iso}"
mkdir -p "$OUT"

# Versione NixOS che usiamo come live installer
NIXOS_VER="25.11"
ARCH="x86_64-linux"
ISO_NAME="nixos-minimal-${NIXOS_VER}.iso"
ISO_URL="https://channels.nixos.org/nixos-${NIXOS_VER}/latest-nixos-minimal-${ARCH}-linux.iso"
SHA_URL="${ISO_URL}.sha256"

echo "[INFO] Download ISO NixOS ${NIXOS_VER} minimal..."
echo "[INFO] Destinazione: $OUT/$ISO_NAME"

if [[ -f "$OUT/$ISO_NAME" ]]; then
  echo "[OK]   ISO già presente, skip download."
else
  curl -L --progress-bar -o "$OUT/$ISO_NAME" "$ISO_URL"
  echo "[OK]   Download completato."
fi

echo "[INFO] Verifico checksum SHA256..."
EXPECTED="$(curl -fsSL "$SHA_URL" | awk '{print $1}')"
ACTUAL="$(sha256sum "$OUT/$ISO_NAME" | awk '{print $1}')"
if [[ "$EXPECTED" == "$ACTUAL" ]]; then
  echo "[OK]   Checksum OK: $ACTUAL"
else
  echo "[ERROR] Checksum MISMATCH!"
  echo "  atteso:   $EXPECTED"
  echo "  ottenuto: $ACTUAL"
  rm -f "$OUT/$ISO_NAME"
  exit 1
fi

echo
echo "ISO pronta: $OUT/$ISO_NAME"
echo "Scrivi su USB con:  bash scripts/write-usb.sh $OUT/$ISO_NAME /dev/sdX"
