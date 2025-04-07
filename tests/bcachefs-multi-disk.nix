{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-multidisk";
  disko-config = ../example/bcachefs-multi-disk.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /")
    # @todo Verify all devices are part of the filesystem
    # @todo Check device labels and group assignments
    # Verify mount options were applied
    machine.succeed("mount | grep ' / ' | grep -q 'compression=lz4'")
    machine.succeed("mount | grep ' / ' | grep -q 'background_compression=lz4'")
    # @todo Verify mountpoint dependency order was respected
  '';
}
