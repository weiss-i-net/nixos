{ self, inputs, ... }: {
  flake.nixosModules.user =
    { config, pkgs, ... }:
    {
      imports = with self.nixosModules; [
        homeManager
        secrets
      ];

      users.users."jannik" = {
        uid = 1000;
        isNormalUser = true;
        description = "Jannik Hiller";
        shell = pkgs.fish;
        hashedPasswordFile = config.sops.secrets."jannik-password".path;
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
        ];
      };

      home-manager.users.jannik = {
        home.stateVersion = "26.05";
        programs.home-manager.enable = true;
      };
    };
}
