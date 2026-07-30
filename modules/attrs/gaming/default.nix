{ self, inputs, ... }: {
  flake.nixosModules.gaming = {
    programs.steam.enable = true;
    programs.gamemode.enable = true;
  };
}
