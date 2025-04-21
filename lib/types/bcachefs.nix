{
  config,
  device,
  diskoLib,
  lib,
  options,
  parent,
  ...
}:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use";
    };
    filesystem = lib.mkOption {
      type = lib.types.str;
      description = "Name of the bcachefs filesystem this partition belongs to";
    };
    # These are passed as arguments to the device corresponding to this one in the invocation of the `bcachefs format` command
    # in the bcachefs_filesystem type defined in bcachefs_filesystem.nix used to format the bcachefs filesystem that this device is a part of.
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to the bcachefs format command";
    };
    # This value is passed to the `--label` option for the device corresponding to this one in the invocation of the `bcachefs format` command
    # in the bcachefs_filesystem type defined in bcachefs_filesystem.nix used to format the bcachefs filesystem that this device is a part of.
    label = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Label to use for this device";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      # Ensures that this file's `_create` will be ran for all member devices that are part of the filesystem being created,
      # before the `_create` in bcachefs_filesystem.nix is ran.
      default = dev: {
        deviceDependencies.bcachefs_filesystems.${config.filesystem} = [ dev ];
      };
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      # The bcachefs_filesystem type defined in bcachefs_filesystem.nix will include this device when formatting and mounting the filesystem.
      # The current file should not run the `bcachefs format` command. Instead, the`bcachefs format` command will be ran
      # in the `_create` attribute in bcachefs_filesystem.nix, once it has collected and generated the arguments specifying the devices that should be part of the filesystem.
      default = ''
        printf "\033[32mDEBUG:\033[0m create bcachefs\n" >&2 2>&1;
        # ls -la /dev/disk/by-partlabel/ >&2 2>&1;
        # printf "bcachefs\nfilesystem: %s\ndevice: %s\n" "${config.filesystem}" "${config.device}" >&2 2>&1;

        # Write device arguments to temporary directory for bcachefs_filesystem
        {
          printf '%s\n' '--label="${config.label}"';
          ${lib.concatMapStrings (args: ''printf '%s\n' '${args}';'') config.extraFormatArgs}
          printf '%s\n' '${config.device}';
        } >> "$disko_devices_dir/bcachefs-${lib.escapeShellArg config.filesystem}";

        # ls -la "$disko_devices_dir";
        # find "$disko_devices_dir" -type f -exec sh -c '
        #   for f do
        #     if file "$f" | grep -q text; then
        #       printf "%s\n" "$f" >&2 2>&1;
        #       cat "$f" >&2 2>&1;
        #       printf "\n" >&2 2>&1;
        #     fi
        #   done
        # ' sh {} +;
        printf "\033[32mDEBUG:\033[0m end create bcachefs\n" >&2 2>&1;
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      # Empty, since mounting will be handled by the bcachefs_filesystem type defined in bcachefs_filesystem.nix.
      default = { };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      # Empty, since unmounting will be handled by the bcachefs_filesystem type defined in bcachefs_filesystem.nix.
      default = { };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      # Empty, since NixOS configuration will be handled by the bcachefs_filesystem type defined in bcachefs_filesystem.nix.
      default = { };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        # # For debugging
        # pkgs.file
      ];
      description = "Packages";
    };
  };
}
