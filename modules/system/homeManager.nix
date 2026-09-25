{ inputs, ... }: {
  flake.nixosModules.homeManager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      # Replace a stale .backup instead of aborting activation on a second collision.
      overwriteBackup = true;
    };
  };
}
