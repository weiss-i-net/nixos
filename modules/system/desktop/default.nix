{ self, inputs, ... }: {
  flake.nixosModules.systemDesktop =
    { config, pkgs, ... }:

    {
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
      };

      hardware.bluetooth.enable = true;

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        adwaita-fonts
        noto-fonts
        noto-fonts-color-emoji
      ];

      environment.variables = {
        XCURSOR_THEME = "Adwaita";
        XCURSOR_SIZE = "24";
      };
    };
}
