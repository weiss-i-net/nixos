{ self, inputs, ... }: {
  flake.nixosModules.nixSettings = {
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      settings.auto-optimise-store = true;
      # This flake lives in a colocated jj repo, where the working copy is
      # always a real commit -- every nix command would otherwise prefix its
      # output with a "Git tree is dirty" warning that means nothing here.
      settings.warn-dirty = false;
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };
  };
}
