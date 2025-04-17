{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdb1 = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            vdb2 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "filesystem_multi";
                label = "group_a.vdb2";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
      vdc = {
        device = "/dev/vdc";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdc1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "filesystem_multi";
                label = "group_a.vdc1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
      vdd = {
        device = "/dev/vdd";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "filesystem_multi";
                label = "group_b.vdd1";
                extraFormatArgs = [
                  "--force"
                ];
              };
            };
          };
        };
      };
      vde = {
        device = "/dev/vde";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "filesystem_vde1";
                label = "group_a.vde1";
              };
            };
          };
        };
      };
    };
    bcachefs_filesystems = {
      filesystem_vde1 = {
        type = "bcachefs_filesystem";
        # Relies on the existence of a subvolume in another filesystem
        mountpoint = "/home/somedir/vde1";
      };
      filesystem_multi = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        mountOptions = [
          "verbose"
        ];
        subvolumes = {
          # Subvolume name is different from mountpoint
          "/rootfs" = {
            mountpoint = "/";
            type = "bcachefs_subvolume";
          };
          # Subvolume name is the same as the mountpoint
          "/home" = {
            mountpoint = "/home";
            type = "bcachefs_subvolume";
          };
          # Sub(sub)volume doesn't need a mountpoint as its parent is mounted
          "/home/user" = {
            type = "bcachefs_subvolume";
          };
          # Parent is not mounted so the mountpoint must be set
          "/nix" = {
            mountpoint = "/nix";
            type = "bcachefs_subvolume";
          };
          # This subvolume will be created but not mounted
          "/test" = {
            type = "bcachefs_subvolume";
          };
        };
      };
    };
  };
}