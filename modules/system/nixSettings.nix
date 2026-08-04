{ self, inputs, ... }: {
  flake.nixosModules.nixSettings = {
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      settings.auto-optimise-store = true;
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };
  };
}
