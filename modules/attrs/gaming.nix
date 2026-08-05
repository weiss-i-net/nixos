_: {
  flake.nixosModules.gaming =
    { pkgs, ... }:
    {
      programs = {
        steam = {
          enable = true;
          gamescopeSession.enable = true;
        };
        gamemode.enable = true;
        gamescope.enable = true;
      };

      # GPU-vendor-specific tuning (fan curves, overdrive) deliberately stays
      # out of this bundle -- it is imported by every gaming-capable host,
      # including Intel ones, so it may only contain things that hold for any
      # GPU. See desktopConfiguration.nix for the amdgpu side.
      environment.systemPackages = with pkgs; [
        discord
        mangohud
      ];
    };
}
