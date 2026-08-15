{ inputs, ... }: {
  flake.nixosModules.homeManager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      # Replace a stale .backup rather than aborting activation when one already
      # exists, which is what a second collision on the same file would do.
      overwriteBackup = true;
    };
  };
}
