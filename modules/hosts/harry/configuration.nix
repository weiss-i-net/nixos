{ self, inputs, ... }: {
  flake.nixosModules.harryConfiguration =
    { config, pkgs, ... }:

    {
      imports = [
        inputs.nixos-hardware.nixosModules.microsoft-surface-common
        self.nixosModules.harryHardware
        self.nixosModules.niri
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      # The IPU3 CIO2 driver's fwnode async notifier completion is recursive:
      # it also waits on ov8865's ancillary VCM (autofocus motor) sub-notifier,
      # which never completes because dw9719 has no ACPI/i2c modalias (only
      # device-tree `of:` aliases), so udev never auto-loads it for the
      # software-node-instantiated VCM device. That one unsatisfied ancillary
      # connection silently blocks CIO2's media-graph links for all 3 sensors,
      # not just the rear camera (confirmed live via media-ctl -p and kernel
      # dynamic debug on v4l2_async/ipu3_cio2/ipu_bridge). Force it to load.
      boot.kernelModules = [ "dw9719" ];
      networking.hostName = "harry"; # Define your hostname.
      networking.networkmanager.enable = true;

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 8 * 1024;
        }
      ];

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
        # The EC drives the fan off Intel DPTF thermal trip points; thermald's
        # --adaptive mode loads the OEM DPTF tables from ACPI so the fan
        # actually idles instead of running constantly (no direct PWM control
        # exists for this hardware).
        thermald.enable = true;
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
        # `cam`/`media-ctl`/`v4l2-ctl` for verifying the IPU3 camera stack
        # (see the ov7251 blacklist above).
        libcamera
        v4l-utils
        self.packages.${pkgs.stdenv.hostPlatform.system}.myNeovim
      ];

      system.stateVersion = "26.05";
    };
}
