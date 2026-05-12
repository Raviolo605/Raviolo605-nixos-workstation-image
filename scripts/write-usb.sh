#!/usr/bin/env bash
# =============================================================================
# write-usb.sh  —  Scrive la ISO NixOS su una chiavetta USB
#
# Uso:  sudo bash scripts/write-usb.sh <iso-file> <usb-device>
# Es.:  sudo bash scripts/write-usb.sh iso/nixos-minimal-25.05.iso /dev/sdb
# =============================================================================
set -euo pipefail

ISO="${1:-}"
DEV="${2:-}"

[[ -z "$ISO" || -z "$DEV" ]] && {
  echo "Uso: sudo bash $0 <iso-file> <usb-device>"
  echo "Dispositivi USB disponibili:"
  lsblk -o NAME,SIZE,MODEL,TRAN | grep -i usb || lsblk -o NAME,SIZE,MODEL
  exit 1
}

[[ $EUID -ne 0 ]] && { echo "[ERROR] Deve girare come root (sudo)"; exit 1; }
[[ -f "$ISO" ]]   || { echo "[ERROR] File ISO non trovato: $ISO"; exit 1; }
[[ -b "$DEV" ]]   || { echo "[ERROR] Dispositivo non trovato: $DEV"; exit 1; }

# Sicurezza: rifiuta dischi di sistema
for MOUNTED in / /home /boot; do
  if mount | grep -q "^$DEV.*$MOUNTED "; then
    echo "[ERROR] $DEV sembra essere un disco di sistema (montato su $MOUNTED). Annullato."
    exit 1
  fi
done

SIZE="$(lsblk -bno SIZE "$DEV" 2>/dev/null | head -1)"
echo "[INFO] Dispositivo: $DEV  ($(( SIZE / 1024 / 1024 / 1024 )) GB)"
echo "[INFO] ISO:         $ISO  ($(du -sh "$ISO" | cut -f1))"
echo
read -rp "ATTENZIONE: $DEV sarà SOVRASCRITTO. Continuare? [scrivi YES] " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Annullato."; exit 0; }

# Smonta eventuali partizioni
umount "${DEV}"* 2>/dev/null || true

echo "[INFO] Scrittura in corso (dd)..."
dd if="$ISO" of="$DEV" bs=4M status=progress oflag=sync
sync

echo
echo "[OK]  Chiavetta pronta: $DEV"
echo "Riavvia il PC, imposta UEFI boot da USB e poi:"
echo "  sudo bash <(curl -fsSL https://raw.githubusercontent.com/Raviolo605/Raviolo605-nixos-workstation-image/main/scripts/install.sh)"

    └── dev-stack.nix