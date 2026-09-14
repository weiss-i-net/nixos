{
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.noctalia = moduleWithSystem (_: {
    home-manager.sharedModules = [
      {
        programs.noctalia = {
          enable = true;
          settings = {
            theme.builtin = "Ayu";

            shell = {
              animation.speed = 2.0;
              panel.open_near_click_control_center = true;
            };

            weather.enabled = false;

            bar.default = {
              start = [
                "wallpaper"
                "workspaces"
              ];
              end = [
                "media"
                "tray"
                "notifications"
                "network"
                "bluetooth"
                "volume"
                "brightness"
                "battery"
                "session"
              ];
            };

            idle = {
              behavior_order = [
                "lock"
                "screen-off"
                "lock-and-suspend"
              ];
              behavior = {
                lock = {
                  action = "lock";
                  enabled = false;
                  timeout = 600.0;
                };
                "screen-off" = {
                  action = "screen_off";
                  enabled = true;
                  timeout = 660.0;
                };
                "lock-and-suspend" = {
                  action = "lock_and_suspend";
                  enabled = false;
                  timeout = 900.0;
                };
              };
            };

            lockscreen_widgets.enabled = false;

            widget = {
              bluetooth.hide_when_no_connected_device = true;
              media.hide_when_no_media = true;
              network.show_label = false;
            };

            wallpaper = {
              directory = ./wallpapers;
              default.path = ./wallpapers/nix-wallpaper-binary-black_8k.png;
            };
          };
        };
      }
    ];
  });

  perSystem =
    { pkgs, ... }:
    {
      packages.myNoctalia = pkgs.noctalia;
    };
}
