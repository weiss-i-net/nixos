{ self, inputs, ... }: {
  flake.nixosModules.base =
    { config, pkgs, ... }:

    {
      imports = [
        self.nixosModules.systemCore
        self.nixosModules.systemAudio
        self.nixosModules.systemNetwork
        self.nixosModules.systemDesktop
        self.nixosModules.systemSecrets
        self.nixosModules.niri
      ];

      users.users."jannik" = {
        isNormalUser = true;
        description = "Jannik Hiller";
        shell = pkgs.fish;
        hashedPasswordFile = config.sops.secrets."jannik-password".path;
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
        ];
        packages = with pkgs; [
          thunderbird
          inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
          self.packages.${pkgs.stdenv.hostPlatform.system}.myJujutsu
          self.packages.${pkgs.stdenv.hostPlatform.system}.myTmux
          claude-code
          zotero
          kdePackages.okular
        ];
      };

      environment.systemPackages = with pkgs; [
        git
        busybox
        fishPlugins.tide
        adwaita-icon-theme
        self.packages.${pkgs.stdenv.hostPlatform.system}.myNeovim
      ];
    };
}
