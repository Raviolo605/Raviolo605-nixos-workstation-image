<div align="center">

# ⚡ NixOS Hyprland Workstation

### *One command. One disk. One complete workstation.*

**Boot a USB → run a script → reboot into your machine.**  
No manual partitioning. No package hunting. No configuration drift. Ever again.

---

[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-58E1FF?style=flat-square)](https://hyprland.org)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Architecture](https://img.shields.io/badge/arch-x86__64-orange?style=flat-square)]()

</div>

---

## What this is

A **production-grade, fully declarative NixOS workstation** — built to reproduce the ergonomics, filesystem layout, and developer tooling of a hand-tuned Gentoo setup, with the reproducibility guarantees of Nix.

You are not installing a generic Linux distro.  
You are **deploying a complete workstation from source**: every service, font, shell alias, desktop keybind, Waybar widget, and compiler flag is declared in one place and built atomically.

> If you break it, `rebuild` fixes it.  
> If you want to replicate it on another machine — it's already in this repo.

---

## Installation flow

```
Your current machine (any Linux)
│
├─ git clone this repo
├─ bash scripts/build-installer.sh   ← downloads NixOS 25.11 ISO
└─ sudo bash scripts/write-usb.sh    ← flashes it to USB
        │
        ▼
  [ Boot USB on target machine — UEFI mode ]
        │
        ▼
  sudo bash <(curl -fsSL …/install.sh)
        │
        ├─ ✔  UEFI + network check
        ├─ ✔  git clone this repo
        ├─ ✔  Disko: GPT + EFI + Btrfs subvolumes
        ├─ ✔  nixos-install --flake .#zen4
        ├─ ✔  copy flake → ~/nixos-gentoo-clone
        └─ ✔  reboot
                │
                ▼
        [ Your new workstation ]
```

---

## The stack

```
┌─────────────────────────────────────────────────────────────────┐
│                         DESKTOP LAYER                           │
│                                                                 │
│  Hyprland (Wayland compositor)  ·  XWayland  ·  hyprpaper      │
│  Waybar (bottom bar)  ·  rofi-wayland  ·  foot terminal        │
│  tuigreet greeter  ·  zsh + starship  ·  tmux  ·  neovim       │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                         AUDIO / GPU                             │
│                                                                 │
│  PipeWire + WirePlumber + ALSA 32-bit compat                    │
│  AMD Mesa · Vulkan · AMDGPU (Radeon 780M tuned)                 │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                      DEVELOPER STACK                            │
│                                                                 │
│  gcc · clang · mold · lld · cmake · meson · ninja              │
│  gdb · valgrind · ccache · pkg-config · perf                   │
│  Python 3 (FastAPI · SQLAlchemy · Celery · pandas · numpy)     │
│  Node.js · pnpm · uv · ruff                                    │
│                                                                 │
│  C/C++ LIBRARIES                                                │
│  boost · eigen · tbb · abseil-cpp · fmt · spdlog               │
│  SDL2 · mesa · libepoxy · shaderc · freetype · harfbuzz        │
│  protobuf · nlohmann_json · simdjson · re2 · libxml2           │
│  openssl · libgcrypt · nettle · gmp · libgit2                  │
│  libuv · libffi · libevent · jemalloc · mimalloc               │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                       SERVICES                                  │
│                                                                 │
│  Docker (overlay2)  ·  libvirt/KVM  ·  QEMU  ·  OVMF          │
│  PostgreSQL 18  ·  Redis (localhost)  ·  Ollama (CPU-first)    │
│  Flatpak  ·  Bluetooth  ·  nftables firewall                   │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                      FILESYSTEM                                 │
│                                                                 │
│  /dev/nvme0n1                                                   │
│  ├── p1  512M  vfat    /boot/efi  (EFI System Partition)       │
│  └── p2  rest  Btrfs                                            │
│           ├── @            →  /                                 │
│           ├── @home        →  /home                             │
│           ├── @var         →  /var                              │
│           └── @snapshots   →  /.snapshots                       │
│                                                                 │
│  Mount options: noatime · compress=zstd:3 · ssd                │
│                 discard=async · space_cache=v2                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## One-liner install

Boot the NixOS live USB on the target machine, then:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Raviolo605/Raviolo605-nixos-workstation-image/main/scripts/install.sh)
```

> ⚠️ **This will erase the target disk.** The installer asks for explicit `YES` confirmation before touching anything.

---

## Full step-by-step

### Step 1 — Clone *(on your current machine)*

```bash
git clone https://github.com/Raviolo605/Raviolo605-nixos-workstation-image.git
cd Raviolo605-nixos-workstation-image
```

### Step 2 — Build a bootable USB *(on your current machine)*

```bash
# Download NixOS 25.11 minimal ISO (~900 MB, SHA256 verified)
bash scripts/build-installer.sh

# Flash to USB — check your device with lsblk first
sudo bash scripts/write-usb.sh iso/nixos-minimal-25.11.iso /dev/sdX
```

### Step 3 — Boot and install *(from the NixOS live environment)*

1. Boot the target machine from USB in **UEFI mode**
2. Connect to Wi-Fi if needed: `nmtui`
3. Run the installer:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Raviolo605/Raviolo605-nixos-workstation-image/main/scripts/install.sh)
```

### Step 4 — First boot

| Action | Command |
|--------|---------|
| **Change password immediately** | `passwd` |
| Apply config changes | `rebuild` |
| Test without activating | `testrebuild` |
| Reload Waybar | `waybar-restart` |
| View Hyprland logs | `hypr-errors` |

> Default login: user `giacomo` · password `changeme`

---

## Customise before install

All variables are at the top of `flake.nix`:

```nix
hostName   = "zen4";            # hostname on the network
username   = "giacomo";         # primary user
diskDevice = "/dev/nvme0n1";    # ⚠ this disk will be wiped
```

**Btrfs tuning** (already optimal for NVMe):
```nix
btrfsOpts = [ "noatime" "compress=zstd:3" "ssd" "discard=async" "space_cache=v2" ];
```
Remove `ssd` and `discard=async` for spinning disks.

---

## Rebuilding after changes

```bash
bash scripts/build-system.sh switch    # apply immediately
bash scripts/build-system.sh boot      # apply on next boot
bash scripts/build-system.sh dry-run   # preview changes only
```

Or from inside the installed system (zsh aliases):

```bash
rebuild       # nixos-rebuild switch --flake ~/nixos-gentoo-clone#zen4
testrebuild   # nixos-rebuild test   --flake ~/nixos-gentoo-clone#zen4
```

---

## Repository layout

```
nixos-workstation-image/
│
├── flake.nix               ← single declarative entrypoint (system + Home Manager)
├── flake.lock              ← pinned dependency graph
│
├── scripts/
│   ├── install.sh          ← automated installer (run from NixOS live ISO)
│   ├── build-installer.sh  ← downloads official NixOS ISO
│   ├── write-usb.sh        ← flashes ISO to USB
│   └── build-system.sh     ← nixos-rebuild wrapper
│
├── hosts/
│   └── zen-clone/          ← host-specific hardware config
│       ├── configuration.nix
│       ├── disko.nix
│       └── hardware-configuration.nix
│
├── modules/                ← NixOS modules
│   ├── boot.nix
│   ├── btrfs.nix
│   ├── desktop-hyprland.nix
│   ├── desktop-waybar.nix
│   ├── dev-tools.nix
│   ├── docker.nix
│   ├── networking.nix
│   ├── ollama.nix
│   ├── postgresql.nix
│   ├── redis.nix
│   ├── security.nix
│   └── users.nix
│
├── profiles/               ← composable profiles
│   ├── base.nix
│   ├── desktop.nix
│   └── workstation.nix
│
└── home/
    └── giacomo.nix         ← Home Manager: shell, dotfiles, Hyprland, Waybar
```

---

## Requirements

| | |
|--|--|
| Architecture | x86_64 |
| Firmware | UEFI (Secure Boot not required) |
| Disk | NVMe recommended · any block device configurable |
| RAM | 8 GB minimum · 16 GB recommended |
| Network | Required during install |

---

## What this does NOT do

- Migrate personal files, browser profiles, or credentials
- Copy SSH keys, API keys, or secrets of any kind
- Set up private services or external accounts

You get a clean, fully functional workstation. **Bring your own data.**

---

<div align="center">

MIT License — see [LICENSE](LICENSE)

</div>
