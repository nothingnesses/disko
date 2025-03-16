{
  config,
  diskoLib,
  device,
  lib,
  options,
  rootMountPoint,
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
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to the file containing the password for encryption";
      example = "/tmp/disk.key";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "A list of options to pass to mount.";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the Bcachefs filesystem to.";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = _dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        # create the filesystem only if the device seems empty
        if ! (blkid "${config.device}" -o export | grep -q '^TYPE='); then
          bcachefs format ${toString config.extraArgs} ${config.device} \
            ${lib.optionalString (config.passwordFile != null) "--encrypted <<<\"$(cat ${config.passwordFile})\""}
        fi
        ${lib.optionalString (config.passwordFile != null) "bcachefs unlock -k session ${config.device} <<<\"$(cat ${config.passwordFile})\""}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {
        fs = lib.optionalAttrs (config.mountpoint != null) {
          ${config.mountpoint} = ''
            if ! findmnt ${config.device} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
              ${lib.optionalString (config.passwordFile != null) "bcachefs unlock -k session ${config.device} <<<\"$(cat ${config.passwordFile})\""}
              mount -t bcachefs ${config.device} "${rootMountPoint}${config.mountpoint}" \
              ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
              -o X-mount.mkdir
            fi
          '';
        };
      };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default = { };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = config.device;
            fsType = "bcachefs";
            options = config.mountOptions;
          };
        })
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.bcachefs-tools ];
      description = "Packages";
    };
  };
}