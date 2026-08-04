{ self, ... }: {
  flake.nixosModules.desktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      fileManager = pkgs.nautilus;
    in
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

      # Reuse the X11 xkb layout above for the TTYs instead of the default
      # us keymap.
      console.useXkbConfig = true;

      hardware.bluetooth.enable = true;

      programs.dconf.enable = true;

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        adwaita-fonts
        noto-fonts
        noto-fonts-color-emoji
      ];

      environment.variables = {
        XCURSOR_THEME = "Adwaita";
        XCURSOR_SIZE = "24";
        # gamescope spawns its own private Xwayland per-instance rather than using
        # niri's, so it doesn't pick up niri's keyboard.xkb config above and falls
        # back to Xwayland's built-in "us" default.
        XKB_DEFAULT_LAYOUT = "de";
        XKB_DEFAULT_OPTIONS = "lv3:caps_switch";
      };

      environment.systemPackages = with pkgs; [
        adwaita-icon-theme
        fileManager
        udiskie # also included here, so the icon gets installed
      ];

      home-manager.sharedModules = [
        {
          dconf.enable = true;
          dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
          services.udiskie = {
            enable = true;
            settings.program_options.file_manager = lib.getExe fileManager;
          };
        }
      ];
    };
}
