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
        discord
        mangohud
        lutris
      ];
    };
}
