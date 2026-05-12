{
  description = "NixOS clone-like workstation inspired by Giacomo's Gentoo Hyprland workstation";

  inputs = {
    # Per Hyprland, Wayland e pacchetti recenti conviene unstable.
    # Se vuoi massima stabilità: sostituisci con github:NixOS/nixpkgs/nixos-25.11
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, disko, home-manager, ... }:
  let
    system = "x86_64-linux";

    # === PERSONALIZZAZIONI MINIME ===
    hostName = "zen4";
    username = "giacomo";

    # ATTENZIONE: Disko distrugge questo disco.
    # Controlla con: lsblk -o NAME,SIZE,MODEL,TYPE
    diskDevice = "/dev/nvme0n1";

    btrfsOpts = [
      "noatime"
      "compress=zstd:3"
      "ssd"
      "discard=async"
      "space_cache=v2"
    ];
  in {
    nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs hostName username diskDevice btrfsOpts;
      };

      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager

        ({ config, pkgs, lib, ... }:
        let
          pythonDev = pkgs.python3.withPackages (ps: with ps; [
            pip
            virtualenv
            requests
            httpx
            fastapi
            uvicorn
            sqlalchemy
            alembic
            celery
            pytest
            pandas
            numpy
            scipy
            matplotlib
            beautifulsoup4
            lxml
          ]);

          postgresqlPackage =
            if pkgs ? postgresql_18 then pkgs.postgresql_18 else pkgs.postgresql;

          codePackage =
            if pkgs ? vscode-with-extensions then
              pkgs.vscode-with-extensions.override {
                vscodeExtensions =
                  (with pkgs.vscode-extensions; [
                    ms-python.python
                    ms-vscode.cpptools
                    ms-azuretools.vscode-docker
                    eamodio.gitlens
                    dbaeumer.vscode-eslint
                    esbenp.prettier-vscode
                  ])
                  ++ lib.optionals (pkgs.vscode-extensions ? ms-vscode) [
                    pkgs.vscode-extensions.ms-vscode.cmake-tools
                  ];
              }
            else
              pkgs.vscode;
        in {
          ######################################################################
          # 0. NIX BASE
          ######################################################################

          system.stateVersion = "25.11";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          nixpkgs.config.allowUnfree = true;

          ######################################################################
          # 1. DISCO: GPT + EFI + BTRFS SUBVOLUMES COME IL TUO GENTOO
          ######################################################################

          disko.devices = {
            disk.main = {
              type = "disk";
              device = diskDevice;

              content = {
                type = "gpt";

                partitions = {
                  ESP = {
                    name = "ESP";
                    size = "512M";
                    type = "EF00";

                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [
                        "noatime"
                        "fmask=0022"
                        "dmask=0022"
                      ];
                    };
                  };

                  root = {
                    name = "nixos-btrfs";
                    size = "100%";

                    content = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];

                      subvolumes = {
                        "@" = {
                          mountpoint = "/";
                          mountOptions = btrfsOpts;
                        };

                        "@home" = {
                          mountpoint = "/home";
                          mountOptions = btrfsOpts;
                        };

                        "@var" = {
                          mountpoint = "/var";
                          mountOptions = btrfsOpts;
                        };

                        "@snapshots" = {
                          mountpoint = "/.snapshots";
                          mountOptions = btrfsOpts;
                        };
                      };
                    };
                  };
                };
              };
            };
          };

          boot.supportedFilesystems = [ "btrfs" ];
          boot.initrd.supportedFilesystems = [ "btrfs" ];

          ######################################################################
          # 2. BOOT UEFI + GRUB, SIMILE ALLA TUA MACCHINA
          ######################################################################

          boot.loader.efi.canTouchEfiVariables = true;
          boot.loader.efi.efiSysMountPoint = "/boot";

          boot.loader.grub = {
            enable = true;
            efiSupport = true;
            device = "nodev";
            useOSProber = false;
            configurationLimit = 10;
          };

          boot.kernelPackages = pkgs.linuxPackages_latest;

          boot.initrd.availableKernelModules = [
            "nvme"
            "xhci_pci"
            "usb_storage"
            "sd_mod"
            "r8169"
            "amdgpu"
          ];

          boot.kernelModules = [
            "amdgpu"
            "kvm-amd"
            "snd_hda_intel"
            "r8169"
            "mt7921e"
          ];

          boot.extraModprobeConfig = ''
            options amdgpu dc=1
          '';

          hardware.cpu.amd.updateMicrocode = true;
          hardware.enableRedistributableFirmware = true;

          ######################################################################
          # 3. AMD GPU / MESA / VULKAN
          ######################################################################

          hardware.graphics = {
            enable = true;
            enable32Bit = true;
            extraPackages = with pkgs; [
              mesa
              vulkan-loader
              vulkan-validation-layers
              vulkan-tools
            ];
          };

          ######################################################################
          # 4. ZRAM, NIENTE SWAP PARTITION
          ######################################################################

          swapDevices = [ ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 25;
            priority = 100;
          };

          services.fstrim.enable = true;

          ######################################################################
          # 5. LOCALIZZAZIONE
          ######################################################################

          time.timeZone = "Europe/Rome";

          i18n.defaultLocale = "en_US.UTF-8";

          i18n.supportedLocales = [
            "en_US.UTF-8/UTF-8"
            "it_IT.UTF-8/UTF-8"
          ];

          i18n.extraLocaleSettings = {
            LC_ADDRESS = "it_IT.UTF-8";
            LC_IDENTIFICATION = "it_IT.UTF-8";
            LC_MEASUREMENT = "it_IT.UTF-8";
            LC_MONETARY = "it_IT.UTF-8";
            LC_NAME = "it_IT.UTF-8";
            LC_NUMERIC = "it_IT.UTF-8";
            LC_PAPER = "it_IT.UTF-8";
            LC_TELEPHONE = "it_IT.UTF-8";
            LC_TIME = "it_IT.UTF-8";
          };

          console.keyMap = "it";

          ######################################################################
          # 6. NETWORKING + FIREWALL
          ######################################################################

          networking.hostName = hostName;
          networking.networkmanager.enable = true;

          networking.nftables.enable = true;

          networking.firewall = {
            enable = true;
            allowedTCPPorts = [ ];
            allowedUDPPorts = [ ];
            allowPing = true;
          };

          services.openssh.enable = false;

          ######################################################################
          # 7. DBUS / POLKIT / ELOGIND-LIKE SESSION MODEL
          ######################################################################

          services.dbus.enable = true;
          security.polkit.enable = true;
          security.rtkit.enable = true;

          services.logind = {
            lidSwitch = "ignore";
            extraConfig = ''
              HandlePowerKey=poweroff
              HandleSuspendKey=suspend
              RuntimeDirectorySize=20%
            '';
          };

          ######################################################################
          # 8. AUDIO: PIPEWIRE + WIREPLUMBER
          ######################################################################

          services.pipewire = {
            enable = true;
            audio.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            wireplumber.enable = true;
          };

          ######################################################################
          # 9. BLUETOOTH
          ######################################################################

          hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
          };

          services.blueman.enable = true;

          ######################################################################
          # 10. HYPRLAND + PORTALS + GREETD
          ######################################################################

          programs.hyprland = {
            enable = true;
            xwayland.enable = true;
          };

          xdg.portal = {
            enable = true;
            extraPortals = with pkgs; [
              xdg-desktop-portal-hyprland
              xdg-desktop-portal-gtk
            ];

            config.common.default = [
              "hyprland"
              "gtk"
            ];
          };

          services.greetd = {
            enable = true;

            settings = {
              default_session = {
                user = "greeter";
                command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
              };
            };
          };

          environment.sessionVariables = {
            NIXOS_OZONE_WL = "1";
            MOZ_ENABLE_WAYLAND = "1";
            QT_QPA_PLATFORM = "wayland;xcb";
            SDL_VIDEODRIVER = "wayland";
            XDG_CURRENT_DESKTOP = "Hyprland";
            XDG_SESSION_DESKTOP = "Hyprland";
            XDG_SESSION_TYPE = "wayland";
          };

          ######################################################################
          # 11. UTENTI
          ######################################################################

          programs.zsh.enable = true;

          users.mutableUsers = true;

          users.users.${username} = {
            isNormalUser = true;
            description = "Giacomo";
            shell = pkgs.zsh;

            extraGroups = [
              "wheel"
              "networkmanager"
              "video"
              "audio"
              "input"
              "docker"
              "libvirtd"
              "kvm"
            ];

            # Cambiala subito dopo il primo boot:
            # passwd giacomo
            initialPassword = "changeme";
          };

          security.sudo.enable = true;
          security.sudo.wheelNeedsPassword = true;

          ######################################################################
          # 12. DOCKER / LIBVIRT / VM WINDOWS
          ######################################################################

          virtualisation.docker = {
            enable = true;
            enableOnBoot = true;
            storageDriver = "overlay2";
          };

          virtualisation.libvirtd = {
            enable = true;

            qemu = {
              package = pkgs.qemu_kvm;
              runAsRoot = false;
              ovmf.enable = true;
              swtpm.enable = true;
            };
          };

          programs.virt-manager.enable = true;

          ######################################################################
          # 13. DATABASE LOCALI
          ######################################################################

          services.postgresql = {
            enable = true;
            package = postgresqlPackage;
            enableTCPIP = false;

            settings = {
              listen_addresses = "localhost";
            };

            authentication = lib.mkOverride 10 ''
              local all all trust
              host  all all 127.0.0.1/32 md5
              host  all all ::1/128      md5
            '';
          };

          services.redis.servers.local = {
            enable = true;
            bind = "127.0.0.1";
            port = 6379;
          };

          ######################################################################
          # 14. OLLAMA LOCALE
          ######################################################################

          services.ollama = {
            enable = true;
            host = "127.0.0.1";
            port = 11434;

            # Per Radeon 780M lascio CPU/default.
            # Se vuoi sperimentare Vulkan/ROCm su NixOS, si fa dopo.
            package =
              if pkgs ? ollama then pkgs.ollama else pkgs.ollama-cpu;
          };

          ######################################################################
          # 15. FLATPAK
          ######################################################################

          services.flatpak.enable = true;

          ######################################################################
          # 16. FONT
          ######################################################################

          fonts.packages = with pkgs; [
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-emoji
            liberation_ttf
            font-awesome
            corefonts
            nerd-fonts.jetbrains-mono
          ];

          ######################################################################
          # 17. PACCHETTI GLOBALI: DESKTOP + DEV + SISTEMA
          ######################################################################

          environment.systemPackages = with pkgs; [
            ####################################################################
            # Base
            ####################################################################
            bash
            zsh
            starship
            git
            curl
            wget
            jq
            yq
            unzip
            zip
            gnutar
            gzip
            bzip2
            xz
            file
            tree
            which
            killall
            pciutils
            usbutils
            smartmontools
            lm_sensors
            lsof
            strace
            socat

            ####################################################################
            # Monitoring
            ####################################################################
            fastfetch
            htop
            btop
            iotop
            ncdu

            ####################################################################
            # Search / terminal workflow
            ####################################################################
            ripgrep
            fd
            fzf
            tmux
            neovim
            eza

            ####################################################################
            # Filesystem / boot
            ####################################################################
            btrfs-progs
            dosfstools
            efibootmgr

            ####################################################################
            # Wayland / Hyprland ecosystem
            ####################################################################
            hyprland
            hyprpaper
            swaybg
            waybar
            foot
            rofi-wayland
            wofi
            wl-clipboard
            cliphist
            grim
            slurp
            swappy
            wf-recorder
            wlr-randr
            xdg-utils
            xdg-user-dirs
            xwayland
            polkit_gnome

            ####################################################################
            # Audio / video
            ####################################################################
            pavucontrol
            alsa-utils
            ffmpeg
            obs-studio
            libcamera
            v4l-utils

            ####################################################################
            # Browser / cloud
            ####################################################################
            google-chrome
            rclone
            dropbox

            ####################################################################
            # IDE
            ####################################################################
            codePackage

            ####################################################################
            # Python backend stack
            ####################################################################
            pythonDev
            uv
            ruff

            ####################################################################
            # Frontend stack
            ####################################################################
            nodejs
            pnpm

            ####################################################################
            # C / C++ toolchain
            ####################################################################
            gcc
            clang
            lld
            mold
            cmake
            meson
            ninja
            gdb
            valgrind
            ccache
            pkg-config
            linuxPackages_latest.perf

            ####################################################################
            # C / C++ libraries  (mirror dei dev-libs / dev-cpp / media-libs Gentoo)
            ####################################################################

            # General-purpose
            boost
            tbb                   # Intel oneTBB (dev-cpp/tbb)
            abseil-cpp            # dev-cpp/abseil-cpp
            jemalloc              # dev-libs/jemalloc
            mimalloc              # dev-libs/mimalloc

            # JSON / config / serialisation
            nlohmann_json         # dev-cpp/nlohmann_json
            jsoncpp               # dev-libs/jsoncpp
            json_c                # dev-libs/json-c
            protobuf              # dev-libs/protobuf
            libyaml               # dev-libs/libyaml
            tomlplusplus          # dev-cpp/tomlplusplus

            # String / parsing
            re2                   # dev-libs/re2
            simdjson              # dev-libs/simdjson
            pcre2                 # dev-libs/libpcre2
            oniguruma             # dev-libs/oniguruma
            icu                   # dev-libs/icu
            libxml2               # dev-libs/libxml2
            libxslt               # dev-libs/libxslt

            # Maths / SIMD / linear algebra
            eigen                 # dev-cpp/eigen

            # Logging / formatting
            fmt                   # dev-libs/libfmt
            spdlog                # dev-libs/spdlog

            # I/O / compression / archive
            libzip                # dev-libs/libzip
            lzo                   # dev-libs/lzo
            xxhash                # dev-libs/xxhash

            # System / IPC / async
            libuv                 # dev-libs/libuv
            libffi                # dev-libs/libffi
            libevent              # dev-libs/libevent
            libusb1               # dev-libs/libusb

            # Crypto / TLS
            openssl               # dev-libs/openssl
            nss                   # dev-libs/nss
            libgcrypt             # dev-libs/libgcrypt
            nettle                # dev-libs/nettle
            gmp                   # dev-libs/gmp

            # Git / VCS
            libgit2               # dev-libs/libgit2

            # Graphics / multimedia libraries
            SDL2                  # media-libs/libsdl2
            SDL                   # media-libs/libsdl
            freeglut              # media-libs/freeglut
            mesa                  # media-libs/mesa (OpenGL, EGL, GLU)
            libepoxy              # media-libs/libepoxy
            shaderc               # media-libs/shaderc
            freetype              # media-libs/freetype
            harfbuzz              # media-libs/harfbuzz
            fontconfig            # media-libs/fontconfig
            libwebp               # media-libs/libwebp
            libpng                # media-libs/libpng
            libjpeg_turbo         # media-libs/libjpeg-turbo
            openjpeg              # media-libs/openjpeg
            libopus               # media-libs/opus
            flac                  # media-libs/flac
            libogg                # media-libs/libogg
            libvorbis             # media-libs/libvorbis

            ####################################################################
            # Containers / VM
            ####################################################################
            docker
            docker-compose
            qemu_kvm
            virt-manager
            virt-viewer
            spice-gtk
            win-virtio

            ####################################################################
            # Apps utili
            ####################################################################
            spotify
            slack
            scrcpy
            wineWowPackages.stable
            winetricks

            ####################################################################
            # AI locale
            ####################################################################
            ollama
          ];

          ######################################################################
          # 18. TMPFILES: STRUTTURA HOME UTENTE
          ######################################################################

          systemd.tmpfiles.rules = [
            "d /home/${username}/PROJECTS 0755 ${username} users - -"
            "d /home/${username}/GoogleDrive 0755 ${username} users - -"
            "d /home/${username}/Dropbox 0755 ${username} users - -"
          ];

          ######################################################################
          # 19. HOME MANAGER: CONFIG HYPRLAND / WAYBAR / SCRIPT
          ######################################################################

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.${username} = { pkgs, lib, ... }: {
            home.stateVersion = "25.11";
            home.username = username;
            home.homeDirectory = "/home/${username}";

            programs.git = {
              enable = true;
              userName = "Giacomo Checchi";
              userEmail = "giacomo.checchi@mail.polimi.it";
            };

            programs.zsh = {
              enable = true;

              shellAliases = {
                ll = "ls -lah";
                gs = "git status";
                rebuild = "sudo nixos-rebuild switch --flake ~/nixos-gentoo-clone#${hostName}";
                testrebuild = "sudo nixos-rebuild test --flake ~/nixos-gentoo-clone#${hostName}";
                waybar-restart = "pkill waybar 2>/dev/null || true; waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css >/tmp/waybar.log 2>&1 &";
                hypr-errors = "hyprctl configerrors";
              };

              initExtra = ''
                eval "$(${pkgs.starship}/bin/starship init zsh)"
              '';
            };

            xdg.enable = true;

            xdg.userDirs = {
              enable = true;
              createDirectories = true;
            };

            ####################################################################
            # HYPRLAND CONFIG BASE
            ####################################################################

            xdg.configFile."hypr/hyprland.conf".text = ''
              # ================================================================
              # Hyprland config - NixOS clone of Gentoo workstation
              # ================================================================

              $mainMod = SUPER
              $terminal = foot
              $menu = rofi -show drun

              monitor=,preferred,auto,1

              env = XDG_CURRENT_DESKTOP,Hyprland
              env = XDG_SESSION_TYPE,wayland
              env = XDG_SESSION_DESKTOP,Hyprland
              env = NIXOS_OZONE_WL,1
              env = MOZ_ENABLE_WAYLAND,1
              env = QT_QPA_PLATFORM,wayland;xcb

              exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
              exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
              exec-once = wl-paste --type text --watch cliphist store
              exec-once = wl-paste --type image --watch cliphist store
              exec-once = hyprpaper || swaybg -c '#050505'
              exec-once = waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css
              exec-once = ~/.local/bin/hypr-icon-restore-daemon

              input {
                  kb_layout = it
                  follow_mouse = 1

                  touchpad {
                      natural_scroll = true
                  }
              }

              general {
                  gaps_in = 4
                  gaps_out = 8
                  border_size = 2
                  layout = dwindle
                  allow_tearing = false
              }

              decoration {
                  rounding = 8
                  active_opacity = 1.0
                  inactive_opacity = 0.96

                  blur {
                      enabled = true
                      size = 4
                      passes = 2
                  }
              }

              animations {
                  enabled = true

                  bezier = fast, 0.05, 0.9, 0.1, 1.05

                  animation = windows, 1, 4, fast
                  animation = border, 1, 5, fast
                  animation = fade, 1, 4, fast
                  animation = workspaces, 1, 4, fast
              }

              dwindle {
                  pseudotile = true
                  preserve_split = true
              }

              misc {
                  force_default_wallpaper = 0
                  disable_hyprland_logo = true
              }

              # ================================================================
              # KEYBINDS
              # ================================================================

              bind = $mainMod, RETURN, exec, $terminal
              bind = $mainMod, D, exec, $menu
              bind = $mainMod, Q, killactive
              bind = $mainMod SHIFT, E, exit
              bind = $mainMod, F, fullscreen
              bind = $mainMod, SPACE, togglefloating
              bind = $mainMod, O, exec, ~/.local/bin/hypr-icon-minimize
              bind = $mainMod, W, exec, google-chrome-stable --app=https://web.whatsapp.com
              bind = $mainMod, C, exec, google-chrome-stable
              bind = $mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy

              bind = $mainMod, 1, workspace, 1
              bind = $mainMod, 2, workspace, 2
              bind = $mainMod, 3, workspace, 3
              bind = $mainMod, 4, workspace, 4
              bind = $mainMod, 5, workspace, 5
              bind = $mainMod, 6, workspace, 6
              bind = $mainMod, 7, workspace, 7
              bind = $mainMod, 8, workspace, 8
              bind = $mainMod, 9, workspace, 9

              bind = $mainMod SHIFT, 1, movetoworkspace, 1
              bind = $mainMod SHIFT, 2, movetoworkspace, 2
              bind = $mainMod SHIFT, 3, movetoworkspace, 3
              bind = $mainMod SHIFT, 4, movetoworkspace, 4
              bind = $mainMod SHIFT, 5, movetoworkspace, 5
              bind = $mainMod SHIFT, 6, movetoworkspace, 6
              bind = $mainMod SHIFT, 7, movetoworkspace, 7
              bind = $mainMod SHIFT, 8, movetoworkspace, 8
              bind = $mainMod SHIFT, 9, movetoworkspace, 9

              bind = , Print, exec, grim -g "$(slurp)" - | swappy -f -
              bind = $mainMod, Print, exec, grim ~/Pictures/screenshot-$(date +%F_%H-%M-%S).png

              # ================================================================
              # MOUSE
              # ================================================================

              bindm = $mainMod, mouse:272, movewindow
              bindm = $mainMod, mouse:273, resizewindow

              # ================================================================
              # WINDOW RULES
              # ================================================================

              windowrulev2 = opacity 0.96 0.96,class:^(foot)$
              windowrulev2 = float,class:^(pavucontrol)$
              windowrulev2 = size 900 600,class:^(pavucontrol)$
            '';

            ####################################################################
            # HYPRPAPER
            ####################################################################

            xdg.configFile."hypr/hyprpaper.conf".text = ''
              preload =
              wallpaper =
              splash = false
            '';

            ####################################################################
            # WAYBAR CONFIG
            ####################################################################

            xdg.configFile."waybar/config".text = builtins.toJSON {
              layer = "top";
              position = "bottom";
              height = 34;
              spacing = 3;

              modules-left = [
                "wlr/taskbar"
              ];

              modules-center = [ ];

              modules-right = [
                "custom/net-active"
                "custom/cpu-temp"
                "custom/gpu-temp"
                "custom/nvme-temp"
                "cpu"
                "memory"
                "disk"
                "pulseaudio"
                "custom/dateclock"
              ];

              "wlr/taskbar" = {
                format = "{icon}";
                icon-size = 18;
                tooltip-format = "{title}";
                on-click = "activate";
                on-click-right = "close";
                on-click-middle = "close";
                all-outputs = true;
                sort-by-app-id = true;
              };

              "custom/net-active" = {
                exec = "~/.config/waybar/scripts/net-active.sh";
                return-type = "json";
                interval = 5;
              };

              "custom/cpu-temp" = {
                exec = "~/.config/waybar/scripts/cpu-temp.sh";
                return-type = "json";
                interval = 5;
              };

              "custom/gpu-temp" = {
                exec = "~/.config/waybar/scripts/gpu-temp.sh";
                return-type = "json";
                interval = 5;
              };

              "custom/nvme-temp" = {
                exec = "~/.config/waybar/scripts/nvme-temp.sh";
                return-type = "json";
                interval = 5;
              };

              cpu = {
                format = " {usage}%";
                tooltip-format = "CPU usage: {usage}%";
                interval = 2;
              };

              memory = {
                format = " {percentage}%";
                tooltip-format = "RAM used: {used:0.1f} GiB / {total:0.1f} GiB";
                interval = 5;
              };

              disk = {
                path = "/";
                format = " {percentage_used}%";
                tooltip-format = "Disk / used: {used} / {total}";
                interval = 30;
              };

              pulseaudio = {
                format = " {volume}%";
                format-muted = " muted";
                tooltip-format = "Audio volume: {volume}%";
                on-click = "pavucontrol";
              };

              "custom/dateclock" = {
                exec = "~/.config/waybar/scripts/dateclock.sh";
                return-type = "json";
                interval = 30;
              };
            };

            xdg.configFile."waybar/style.css".text = ''
              * {
                border: none;
                border-radius: 0;
                font-family: "Impact", "Arial Black", "Liberation Sans", "JetBrainsMono Nerd Font", "Font Awesome 6 Free", sans-serif;
                font-size: 12px;
                font-weight: 900;
                min-height: 0;
              }

              window#waybar {
                background: rgba(5, 7, 10, 0.92);
                color: #e5e7eb;
                border-top: 1px solid #2a3140;
              }

              #taskbar,
              #custom-net-active,
              #custom-cpu-temp,
              #custom-gpu-temp,
              #custom-nvme-temp,
              #cpu,
              #memory,
              #disk,
              #pulseaudio,
              #custom-dateclock {
                background: #111318;
                color: #e5e7eb;
                border: 1px solid #2a3140;
                border-radius: 7px;
                padding: 3px 8px;
                margin: 4px 2px;
              }

              #taskbar button {
                background: #111318;
                color: #e5e7eb;
                border: 1px solid #2a3140;
                border-radius: 7px;
                padding: 2px 6px;
                margin: 3px 2px;
              }

              #taskbar button.active {
                background: #2a1705;
                border: 1px solid #f97316;
                color: #ffffff;
              }

              #taskbar button:hover,
              #custom-net-active:hover,
              #custom-cpu-temp:hover,
              #custom-gpu-temp:hover,
              #custom-nvme-temp:hover,
              #cpu:hover,
              #memory:hover,
              #disk:hover,
              #pulseaudio:hover,
              #custom-dateclock:hover {
                background: #241407;
                border-color: #f97316;
                color: #ffffff;
              }

              .warning {
                color: #fbbf24;
              }

              .critical {
                color: #ef4444;
              }

              .ok {
                color: #22c55e;
              }

              .off {
                color: #9ca3af;
              }
            '';

            ####################################################################
            # WAYBAR SCRIPTS
            ####################################################################

            home.file.".config/waybar/scripts/net-active.sh" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                IFACE="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"

                if [ -z "$IFACE" ] || [ "$IFACE" = "lo" ]; then
                  printf '{"text":"󰖪 OFF","class":"off","tooltip":"No default network route"}\n'
                  exit 0
                fi

                IP="$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2; exit}')"

                case "$IFACE" in
                  en*|eth*) LABEL="ETH" ;;
                  wl*) LABEL="WIFI" ;;
                  usb*|enx*) LABEL="USB" ;;
                  *) LABEL="NET" ;;
                esac

                printf '{"text":"󰈀 %s","class":"ok","tooltip":"Interface: %s | IP: %s"}\n' "$LABEL" "$IFACE" "$IP"
              '';
            };

            home.file.".config/waybar/scripts/cpu-temp.sh" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                T="$(sensors 2>/dev/null | awk '/Tctl:/ {gsub(/[+°C]/,"",$2); print int($2); exit}')"
                [ -z "$T" ] && T="?"
                CLASS="normal"
                [ "$T" != "?" ] && [ "$T" -ge 70 ] && CLASS="warning"
                [ "$T" != "?" ] && [ "$T" -ge 85 ] && CLASS="critical"
                printf '{"text":" CPU %s°","tooltip":"CPU temperature: %s°C","class":"%s"}\n' "$T" "$T" "$CLASS"
              '';
            };

            home.file.".config/waybar/scripts/gpu-temp.sh" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                T="$(sensors 2>/dev/null | awk '
                  /amdgpu-pci/ {gpu=1}
                  gpu && /edge:/ {gsub(/[+°C]/,"",$2); print int($2); exit}
                ')"
                [ -z "$T" ] && T="?"
                CLASS="normal"
                [ "$T" != "?" ] && [ "$T" -ge 70 ] && CLASS="warning"
                [ "$T" != "?" ] && [ "$T" -ge 85 ] && CLASS="critical"
                printf '{"text":" GPU %s°","tooltip":"GPU temperature: %s°C","class":"%s"}\n' "$T" "$T" "$CLASS"
              '';
            };

            home.file.".config/waybar/scripts/nvme-temp.sh" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                T="$(sensors 2>/dev/null | awk '
                  /nvme-pci/ {nvme=1}
                  nvme && /Composite:/ {gsub(/[+°C]/,"",$2); print int($2); exit}
                ')"
                [ -z "$T" ] && T="?"
                CLASS="normal"
                [ "$T" != "?" ] && [ "$T" -ge 60 ] && CLASS="warning"
                [ "$T" != "?" ] && [ "$T" -ge 75 ] && CLASS="critical"
                printf '{"text":" NVMe %s°","tooltip":"NVMe temperature: %s°C","class":"%s"}\n' "$T" "$T" "$CLASS"
              '';
            };

            home.file.".config/waybar/scripts/dateclock.sh" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                TEXT="$(date '+%d.%m.%Y  %H:%M')"
                TIP="$(date '+%A %d %B %Y - ore %H:%M')"
                printf '{"text":" %s","tooltip":"%s","class":"normal"}\n' "$TEXT" "$TIP"
              '';
            };

            ####################################################################
            # MINIMIZE / RESTORE HYPRLAND
            ####################################################################

            home.file.".local/bin/hypr-icon-minimize" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail

                STATE_DIR="$XDG_RUNTIME_DIR/hypr-icon-minimize"
                mkdir -p "$STATE_DIR"

                WIN="$(hyprctl activewindow -j 2>/dev/null || true)"
                ADDR="$(printf '%s' "$WIN" | jq -r '.address // empty')"

                if [ -z "$ADDR" ] || [ "$ADDR" = "null" ]; then
                  exit 0
                fi

                ID="$(printf '%s' "$ADDR" | sed 's/^0x//')"
                printf '%s\n' "$WIN" > "$STATE_DIR/$ID.json"

                hyprctl dispatch movetoworkspacesilent "special:minw_$ID,address:$ADDR" >/dev/null
              '';
            };

            home.file.".local/bin/hypr-icon-restore-daemon" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail

                LOG="/tmp/hypr-icon-restore-daemon.log"
                STATE_DIR="$XDG_RUNTIME_DIR/hypr-icon-minimize"
                mkdir -p "$STATE_DIR"

                echo "restore daemon started at $(date)" >> "$LOG"

                while true; do
                  if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                    sleep 2
                    continue
                  fi

                  SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

                  if [ ! -S "$SOCK" ]; then
                    sleep 2
                    continue
                  fi

                  socat -U - UNIX-CONNECT:"$SOCK" 2>>"$LOG" | while read -r EVENT; do
                    case "$EVENT" in
                      activewindowv2*|workspace*)
                        WIN="$(hyprctl activewindow -j 2>/dev/null || true)"
                        ADDR="$(printf '%s' "$WIN" | jq -r '.address // empty')"
                        WS="$(printf '%s' "$WIN" | jq -r '.workspace.name // empty')"

                        case "$WS" in
                          special:minw_*)
                            ID="$(printf '%s' "$WS" | sed 's/^special:minw_//')"
                            STATE="$STATE_DIR/$ID.json"

                            if [ -f "$STATE" ]; then
                              ORIG_WS="$(jq -r '.workspace.name // .workspace.id // "1"' "$STATE")"
                              ORIG_MON="$(jq -r '.monitor // empty' "$STATE")"

                              [ -n "$ORIG_MON" ] && hyprctl dispatch focusmonitor "$ORIG_MON" >/dev/null 2>&1 || true
                              [ -n "$ORIG_MON" ] && hyprctl dispatch moveworkspacetomonitor "$ORIG_WS" "$ORIG_MON" >/dev/null 2>&1 || true

                              hyprctl dispatch movetoworkspace "$ORIG_WS,address:$ADDR" >/dev/null 2>&1 || true
                              hyprctl dispatch focuswindow "address:$ADDR" >/dev/null 2>&1 || true

                              rm -f "$STATE"
                              echo "restored $ADDR to $ORIG_WS on $ORIG_MON" >> "$LOG"
                            fi
                            ;;
                        esac
                        ;;
                    esac
                  done

                  sleep 1
                done
              '';
            };

            ####################################################################

            ####################################################################

            xdg.configFile."rofi/config.rasi".text = ''
              configuration {
                modi: "drun,run,window";
                show-icons: true;
                terminal: "foot";
                drun-display-format: "{icon} {name}";
              }

              * {
                background: #050505;
                foreground: #f5f5f5;
                accent: #f97316;
                border: #2a3140;
              }

              window {
                width: 45%;
                border: 2px;
                border-color: @accent;
                border-radius: 8px;
                background-color: @background;
              }

              mainbox {
                padding: 12px;
                background-color: @background;
              }

              inputbar {
                padding: 8px;
                border: 1px;
                border-color: @border;
                background-color: #111318;
              }

              listview {
                lines: 10;
                padding: 8px;
                background-color: @background;
              }

              element {
                padding: 8px;
                border-radius: 6px;
              }

              element selected {
                background-color: #241407;
                text-color: @foreground;
              }
            '';

            ####################################################################
            # FOOT TERMINAL
            ####################################################################

            xdg.configFile."foot/foot.ini".text = ''
              font=JetBrainsMono Nerd Font:size=11
              pad=8x8

              [colors]
              background=050505
              foreground=e5e7eb
              regular0=111318
              regular1=ef4444
              regular2=22c55e
              regular3=f59e0b
              regular4=3b82f6
              regular5=a855f7
              regular6=06b6d4
              regular7=e5e7eb
              bright0=4b5563
              bright1=f87171
              bright2=4ade80
              bright3=fbbf24
              bright4=60a5fa
              bright5=c084fc
              bright6=22d3ee
              bright7=ffffff
            '';
          };
        })
      ];
    };
  };
}
    └── services.nix