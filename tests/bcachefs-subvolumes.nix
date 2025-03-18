{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-subvolumes";
  disko-config = ../example/bcachefs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("ls /");
    # there is no subcommand for checking a subvolume, but only subvolumes can be snapshotted
    machine.succeed("bcachefs subvolume snapshot /rootfs /rootfs.snap");
    machine.succeed("bcachefs subvolume snapshot /home /home.snap");
    machine.succeed("bcachefs subvolume snapshot /home/user /home/user.snap");
    # machine.succeed("bcachefs subvolume snapshot /nix /nix.snap");
    machine.succeed("bcachefs subvolume snapshot /test /test.snap");
    # ensure this behavior doesn't change
    machine.succeed("ls /srv");
    machine.fail("bcachefs subvolume snapshot /srv /srv.snap");
  '';
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
  extraSystemConfig = {
    environment.systemPackages = [ pkgs.bcachefs-tools ];
  };
}
