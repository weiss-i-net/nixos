{ self, ... }: {
  flake.nixosModules.gaming =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        prismlauncher
      ];
      programs = {
        steam = {
          enable = true;
          gamescopeSession.enable = true;
        };
        gamemode.enable = true;
        gamescope.enable = true;
      };

      # GPU-vendor tuning stays out: this is imported by Intel hosts too.
      environment.systemPackages = with pkgs; [
        # Separate derivation from gamescope, which sets ENABLE_GAMESCOPE_WSI=1
        # on its children regardless; without the layer installed that variable
        # points at nothing and presentation falls back through Xwayland.
        gamescope-wsi
        discord
        mangohud
        lutris
      ];
    };
}
