{ disks ? [ "/dev/nvme0n1" ], ... }:

{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = builtins.elemAt disks 0;

      content = {
        type = "gpt";

        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "noatime" ];
            };
          };

          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];

              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "noatime"
                    "compress=zstd:3"
                    "ssd"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };

                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "noatime"
                    "compress=zstd:3"
                    "ssd"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };

                "@var" = {
                  mountpoint = "/var";
                  mountOptions = [
                    "noatime"
                    "compress=zstd:3"
                    "ssd"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };

                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "noatime"
                    "compress=zstd:3"
                    "ssd"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}