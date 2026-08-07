{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.noctalia = moduleWithSystem (
    { self', ... }:
    {
      home-manager.sharedModules = [
        inputs.noctalia.homeModules.default
        {
          programs.noctalia = {
            enable = true;
            package = self'.packages.myNoctalia;
            # Ported from `noctalia config export merged` -- preferences only.
            # The app-managed runtime keys stay out on purpose: the lockscreen
            # widget geometry is per-output (DP-1 here, eDP-1 on harry) and this
            # module is shared by both hosts, and wallpaper.last/monitors record
            # absolute /home paths that would not survive evaluation.
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
    }
  );

  perSystem =
    { system, ... }:
    {
      # A plain re-export, not a wrapper-modules wrap -- the "my" prefix is only
      # kept so the package name matches every other feature module (and so the
      # checks in modules/checks.nix pick it up). Once nixpkgs ships noctalia 5,
      # this and the flake input can both go away in favour of pkgs.noctalia.
      packages.myNoctalia = inputs.noctalia.packages.${system}.default;
    };
}
