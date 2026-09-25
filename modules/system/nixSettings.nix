_: {
  flake.nixosModules.nixSettings = {
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      settings.auto-optimise-store = true;
      # The jj working copy is always a real commit, so the dirty-tree warning
      # every nix command would print means nothing here.
      settings.warn-dirty = false;
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };
  };
}
