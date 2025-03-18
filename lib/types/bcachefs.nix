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
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "A list of options to pass to mount.";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              # @todo Add mountOptions for subvolumes
              name = lib.mkOption {
                type = lib.types.str;
                default = config._module.args.name;
                description = "Name of the bcachefs subvolume.";
              };
              type = lib.mkOption {
                type = lib.types.enum [ "bcachefs_subvol" ];
                default = "bcachefs_subvol";
                internal = true;
                description = "Type";
              };
              mountpoint = lib.mkOption {
                type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
                default = null;
                description = "Location to mount the subvolume to.";
              };
            };
          }
        )
      );
      default = { };
      description = "Subvolumes to define for bcachefs.";
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
    # @todo Use `bcachefs setattr` to set inode options from mountOptions on subvolumes
    # @see https://bcachefs-docs.readthedocs.io/en/latest/options.html#file-and-directory-options
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! (blkid "${config.device}" -o export | grep -q '^TYPE='); then
          bcachefs format ${toString config.extraArgs} ${config.device}
        fi
        ${lib.optionalString (config.subvolumes != { }) ''
          if (blkid "${config.device}" -o export | grep -q '^TYPE=bcachefs$'); then
            MNTPOINT="$(mktemp -d)";
            mount -t bcachefs "${config.device}" "$MNTPOINT";
            trap 'rm -fr "$TMPSUBVOL"; umount $MNTPOINT; rm -rf $MNTPOINT' EXIT;
            ${lib.concatMapStrings (subvol: ''
              SUBVOL_ABS_PATH="$MNTPOINT/${subvol.name}";
              mkdir -p "$(dirname "$SUBVOL_ABS_PATH")";
              TMPSUBVOL="$(mktemp -du)";
              if test ! -d "$SUBVOL_ABS_PATH" && ! bcachefs subvolume snapshot "$SUBVOL_ABS_PATH" "$TMPSUBVOL" > /dev/null 2>&1; then
                bcachefs subvolume create "$SUBVOL_ABS_PATH";
              fi
              rm -fr "$TMPSUBVOL";
            '') (lib.attrValues config.subvolumes)}
          fi
        ''}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          subvolMounts = lib.concatMapAttrs (
            _: subvol:
              lib.optionalAttrs
              (subvol.mountpoint != null)
              {
                ${subvol.mountpoint} = ''
                  if ! findmnt "${config.device}" "${rootMountPoint}${subvol.mountpoint}" > /dev/null 2>&1; then
                    mount -t bcachefs "${config.device}" "${rootMountPoint}${subvol.mountpoint}" \
                    -o X-mount.subdir=${subvol.name} \
                    -o X-mount.mkdir
                  fi
                '';
              }
          ) config.subvolumes;
        in
        {
          fs =
            subvolMounts
            // lib.optionalAttrs (config.mountpoint != null) {
              ${config.mountpoint} = ''
                if ! findmnt "${config.device}" "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                  mount -t bcachefs "${config.device}" "${rootMountPoint}${config.mountpoint}" \
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
        (map (
          subvol:
          lib.optional (subvol.mountpoint != null) {
            fileSystems.${subvol.mountpoint} = {
              device = config.device;
              fsType = "bcachefs";
              options = [ "X-mount.subdir=${subvol.name}" ];
            };
          }
        ) (lib.attrValues config.subvolumes))
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