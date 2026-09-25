{ self, ... }: {
  flake.nixosModules.desktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = with self.nixosModules; [
        niri
        noctalia
        homeManager
        core
        user
      ];
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
        gvfs.enable = true;
        udisks2.enable = true;
      };

      # Reuse the layout above for the TTYs instead of the us default.
      console.useXkbConfig = true;

      hardware.bluetooth.enable = true;

      programs.dconf.enable = true;

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        adwaita-fonts
        noto-fonts
        noto-fonts-color-emoji
      ];

      # sessionVariables, not variables: greetd launches niri-session without a
      # login shell, so /etc/set-environment is never sourced.
      environment.sessionVariables = {
        XCURSOR_THEME = "Adwaita";
        XCURSOR_SIZE = "24";
        # gamescope's own Xwayland doesn't pick up niri's xkb config.
        XKB_DEFAULT_LAYOUT = "de";
        XKB_DEFAULT_OPTIONS = "lv3:caps_switch";
        QT_QPA_PLATFORMTHEME = "gtk3";
      };

      environment.systemPackages = with pkgs; [
        adwaita-icon-theme
        nautilus
      ];

      home-manager.sharedModules = [
        {
          dconf.enable = true;
          services.udiskie = {
            enable = true;
            settings.program_options.file_manager = lib.getExe pkgs.nautilus;
          };
          gtk = {
            enable = true;
            colorScheme = "dark";
            theme = {
              package = pkgs.gnome-themes-extra;
              name = "Adwaita-dark";
            };
          };
        }
      ];
    };
}
