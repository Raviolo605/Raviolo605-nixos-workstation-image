#!/usr/bin/env bash
# =============================================================================
# install.sh  —  NixOS automated installer
#
# Esegui da una live NixOS (ISO minimale o full):
#
#   sudo bash <(curl -fsSL https://raw.githubusercontent.com/Raviolo605/Raviolo605-nixos-workstation-image/main/scripts/install.sh)
#
# oppure, se hai già il repo:
#
#   sudo bash scripts/install.sh
#
# ATTENZIONE: DISTRUGGE il disco target (default: /dev/nvme0n1).
# Controlla con:  lsblk -o NAME,SIZE,MODEL,TYPE
# =============================================================================
set -euo pipefail

##############################################################################
# CONFIGURAZIONE — cambia qui se necessario
##############################################################################
FLAKE_REPO="https://github.com/Raviolo605/Raviolo605-nixos-workstation-image"
FLAKE_BRANCH="main"
FLAKE_HOST="zen4"                     # deve corrispondere a hostName nel flake
DISK="/dev/nvme0n1"                   # ATTENZIONE: viene azzerato
REPO_DIR="/tmp/nixos-workstation-image"

##############################################################################
# COLORI / OUTPUT
##############################################################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}   $*"; }
die()   { echo -e "${RED}[ERROR]${RESET}  $*" >&2; exit 1; }
banner(){ echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
          echo -e "${BOLD}${CYAN}  $*${RESET}"; \
          echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}\n"; }

##############################################################################
# PREFLIGHT
##############################################################################
banner "NixOS Workstation Installer"

[[ $EUID -ne 0 ]] && die "Deve girare come root (sudo bash install.sh)"

[[ -d /sys/firmware/efi ]] || die "Il sistema non è avviato in modalità UEFI. Riavvia in UEFI."

info "Disco target: ${BOLD}$DISK${RESET}"
lsblk -o NAME,SIZE,MODEL,TYPE "$DISK" 2>/dev/null || true
echo
read -rp "$(echo -e "${RED}ATTENZIONE: $DISK sarà DISTRUTTO. Continuare? [scrivi YES] ${RESET}")" CONFIRM
[[ "$CONFIRM" == "YES" ]] || { info "Annullato."; exit 0; }

##############################################################################
# RETE
##############################################################################
banner "1/6 — Verifica rete"

if ! ping -c1 -W3 1.1.1.1 &>/dev/null; then
  warn "Nessuna connessione rilevata."
  warn "Se sei su WiFi, connettiti con: nmtui  (poi ri-esegui questo script)"
  die "Rete non disponibile."
fi
ok "Rete OK"

##############################################################################
# DIPENDENZE LIVE
##############################################################################
banner "2/6 — Dipendenze live"

# Assicura git e nix con flakes disponibili
if ! command -v git &>/dev/null; then
  info "Installo git nell'ambiente live..."
  nix-env -iA nixos.git 2>/dev/null || nix-env -iA nixpkgs.git
fi

# Abilita flakes nella sessione corrente se non già attivo
export NIX_CONFIG="experimental-features = nix-command flakes"
ok "Flakes attivi"

##############################################################################
# CLONE / AGGIORNAMENTO REPO
##############################################################################
banner "3/6 — Recupero flake"

# Se lo script è stato eseguito dall'interno del repo già clonato, usalo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../flake.nix" ]]; then
  REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  info "Uso repo locale: $REPO_DIR"
else
  if [[ -d "$REPO_DIR/.git" ]]; then
    info "Aggiorno repo esistente in $REPO_DIR ..."
    git -C "$REPO_DIR" pull --ff-only
  else
    info "Clono $FLAKE_REPO ..."
    git clone --depth=1 --branch "$FLAKE_BRANCH" "$FLAKE_REPO" "$REPO_DIR"
  fi
fi

[[ -f "$REPO_DIR/flake.nix" ]] || die "flake.nix non trovato in $REPO_DIR"
ok "Flake pronto in $REPO_DIR"

##############################################################################
# PARTIZIONAMENTO E FORMATTAZIONE CON DISKO
##############################################################################
banner "4/6 — Partizionamento disco (disko)"

info "Eseguo disko su $DISK ..."

# Sostituisce diskDevice nel flake se diverso dal default — approccio sicuro:
# passiamo il device tramite specialArgs già nel flake, quindi usiamo nix run.
nix run --extra-experimental-features "nix-command flakes" \
    "github:nix-community/disko/latest#disko-install" -- \
    --mode disko \
    --flake "$REPO_DIR#$FLAKE_HOST" \
    2>&1 | tee /tmp/disko.log \
  || {
    # disko-install non disponibile in tutte le versioni: fallback
    warn "disko-install non disponibile, uso disko standalone..."
    nix run --extra-experimental-features "nix-command flakes" \
        "github:nix-community/disko/latest" -- \
        --mode disko \
        --flake "$REPO_DIR#$FLAKE_HOST" \
        2>&1 | tee /tmp/disko.log
    DISKO_STANDALONE=1
  }

ok "Disco partizionato e formattato"

##############################################################################
# GENERAZIONE hardware-configuration (se disko standalone)
##############################################################################
if [[ "${DISKO_STANDALONE:-0}" == "1" ]]; then
  banner "4b/6 — Montaggio e hardware-configuration"

  info "Monto il sistema in /mnt ..."
  # disko solo formatta ma non monta — rimonta
  # I mountpoint sono già definiti nel flake (btrfs subvolumes)
  # Disko li ha creati; li montiamo manualmente se serve
  mount | grep -q "/mnt " || {
    warn "Il disco non risulta montato su /mnt."
    info "Tento montaggio manuale di $DISK..."
    mount -o subvol=@,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
        "${DISK}p2" /mnt 2>/dev/null \
      || mount -o subvol=@,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
             "${DISK}2" /mnt
    mkdir -p /mnt/{boot,home,var,.snapshots}
    mount "${DISK}p1"  /mnt/boot 2>/dev/null || mount "${DISK}1" /mnt/boot
    mount -o subvol=@home,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
        "${DISK}p2"    /mnt/home 2>/dev/null \
      || mount -o subvol=@home,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
             "${DISK}2" /mnt/home
    mount -o subvol=@var,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
        "${DISK}p2"    /mnt/var  2>/dev/null \
      || mount -o subvol=@var,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
             "${DISK}2" /mnt/var
    mount -o subvol=@snapshots,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
        "${DISK}p2"    /mnt/.snapshots 2>/dev/null \
      || mount -o subvol=@snapshots,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2 \
             "${DISK}2" /mnt/.snapshots
  }

  info "Genero hardware-configuration.nix ..."
  nixos-generate-config --root /mnt --no-filesystems 2>/dev/null \
    || nixos-generate-config --root /mnt
  cp /mnt/etc/nixos/hardware-configuration.nix \
     "$REPO_DIR/hosts/zen-clone/hardware-configuration.nix" 2>/dev/null || true
  ok "hardware-configuration generata"
fi

##############################################################################
# INSTALLAZIONE
##############################################################################
banner "5/6 — nixos-install"

info "Avvio nixos-install --flake $REPO_DIR#$FLAKE_HOST ..."
info "(può volerci 20-40 minuti a seconda della connessione)"

nixos-install \
  --no-root-passwd \
  --flake "$REPO_DIR#$FLAKE_HOST" \
  2>&1 | tee /tmp/nixos-install.log

ok "Installazione completata"

##############################################################################
# COPIA FLAKE SUL DISCO INSTALLATO
##############################################################################
banner "6/6 — Copia flake nella home"

DEST="/mnt/home/giacomo/nixos-gentoo-clone"
mkdir -p "$DEST"
cp -r "$REPO_DIR/." "$DEST/"
# Fix permessi (chroot non ancora disponibile, uid/gid fissato)
# Lo user giacomo sarà uid 1000 su un sistema NixOS standard
chown -R 1000:100 "$DEST" 2>/dev/null || true
ok "Flake copiato in $DEST (alias ~/nixos-gentoo-clone)"
info "Dopo il boot usa: rebuild  (alias già configurato in zsh)"

##############################################################################
# FINE
##############################################################################
banner "Installazione completata!"

echo -e "${GREEN}Il sistema è installato su $DISK.${RESET}"
echo
echo -e "  ${BOLD}Prossimi passi:${RESET}"
echo -e "  1. ${CYAN}reboot${RESET}  (rimuovi la USB quando il BIOS lo chiede)"
echo -e "  2. Accedi come ${BOLD}giacomo${RESET} con password temporanea: ${YELLOW}changeme${RESET}"
echo -e "  3. Cambia la password subito:  ${CYAN}passwd${RESET}"
echo -e "  4. Per rebuild:  ${CYAN}rebuild${RESET}  (alias zsh già configurato)"
echo
read -rp "Vuoi riavviare ora? [Y/n] " REBOOT
[[ "${REBOOT,,}" != "n" ]] && reboot
