{ self, inputs, ... }: {
  flake.nixosModules.common =
    { config, pkgs, ... }:

    {
      imports = [
        self.nixosModules.niri
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      networking.networkmanager.enable = true;

      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };

      services = {
        greetd = {
          enable = true;
          settings = {
            default_session = {
              command = "${config.programs.niri.package}/bin/niri-session";
              user = "jannik";
            };
          };
        };
        xserver.xkb = {
          layout = "de";
          variant = "";
          options = "lv3:caps_switch";
        };
        printing.enable = true;
        upower.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };
      security.rtkit.enable = true;

      programs.fish.enable = true;

      users.users."jannik" = {
        isNormalUser = true;
        description = "Jannik Hiller";
        shell = pkgs.fish;
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

      environment.systemPackages = with pkgs; [
        git
        busybox
        fishPlugins.tide
        self.packages.${pkgs.stdenv.hostPlatform.system}.myNeovim
      ];

      system.stateVersion = "26.05";
    };
}
