{
  config,
  diskoLib,
  lib,
  options,
  parent,
  rootMountPoint,
  # @todo Add any other parameters here, if needed
  ...
}: {
  options = {
    # @todo Add any other options here, if needed
    # @todo Check that this implementation is correct:
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Path of the subvolume";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs_subvolume" ];
      internal = true;
      description = "Type";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "X-mount.mkdir"
        "X-mount.subdir=${config.name}"
      ];
      description = "Options to pass to mount";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the subvolume to";
    };
    # @todo Check that this implementation is correct:
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      # @todo We need to ensure that the scripts in `_create` and `_mount` in bcachefs_filesystem.nix
      # has been ran for the bcachefs filesystem containing this subvolume,
      # before the `_create` in this file is ran.
      default = dev: {
        deviceDependencies.bcachefs_filesystems.${config._parent.name} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      # @todo This needs to temporarily mount the bcachefs filesystem
      # that will contain the subvolume to be made to a temporary directory,
      # only then should it attempt to create the subvolume
      # from inside of that directory.
      default = ''
        # Debugging
        printf "bcachefs_subvolume\n">&2 2>&1;
        printf "name: %s\n" "${config.name}" >&2 2>&1;
        ls -la "${config.name}" >&2 2>&1;

        # @todo Test if the subvolume's path already exists,
        # by creating a snapshot of it to a temporary directory,
        # since only subvolumes can successfully be snapshotted.
        TEMPDIR="$(mktemp -d)";
        trap 'rm -fr "$TEMPDIR";' EXIT;
        if ! bcachefs subvolume snapshot "${config.name}" "$TEMPDIR/" >&2 2>&1; then
          # Create all ancestor directories.
          mkdir -p -- "$(dirname -- "${config.name}")";
          # Create subvolume
          bcachefs subvolume create "${config.name}";
        fi;

        # Debugging
        ls -la "${config.name}" >&2 2>&1;
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      # @todo Check that this implementation is correct:
      default = lib.optionalAttrs (config.mountpoint != null) {
        dev = ''
        '';
        fs.${config.mountpoint} = ''
          # Debugging
          mount >&2 2>&1;

          if ! findmnt "${rootMountPoint}${config.mountpoint}" >&2 2>&1; then
            # @todo Figure out why `X-mount.mkdir` doesn't seem to be working, necessitating `mkdir` here.
            # mkdir -p "${rootMountPoint}${config.mountpoint}";
            ${lib.optionalString (config._parent.passwordFile != null) ''bcachefs unlock -k session "/dev/disk/by-uuid/${config._parent.uuid}" < "${config._parent.passwordFile}";''}
            bcachefs mount \
              -o "${lib.concatStringsSep "," (["X-mount.mkdir" "X-mount.subdir=${config.name}"] ++ config.mountOptions)}" \
              UUID="${config._parent.uuid}" \
              "${rootMountPoint}${config.mountpoint}";
          fi;

          # Debugging
          mount >&2 2>&1;
        '';
      };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      # @todo Check that this implementation is correct:
      default = lib.optionalAttrs (config.mountpoint != null) {
        fs."${config.mountpoint}" = ''
          umount ${config.mountpoint};
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      # @todo Check that this implementation is correct:
      default = lib.optional (config.mountpoint != null) {
        fileSystems.${config.mountpoint} = {
          device = "UUID=${config._parent.uuid}";
          fsType = "bcachefs";
          options = ["X-mount.mkdir" "X-mount.subdir=${config.name}"] ++ config.mountOptions;
        };
      };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      # @todo Check that this implementation is correct:
      default = pkgs: [pkgs.util-linux];
      description = "Packages";
    };
  };
}