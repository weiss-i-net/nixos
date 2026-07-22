{ self, inputs, ... }: {
  flake.nixosModules.niri = { pkgs, lib, ... }: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };
    systemd.user.services.niri.enableDefaultPath = false;
  };

  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    {
      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings =
          let
            kitty = lib.getExe self'.packages.myKitty;
            noctalia = lib.getExe self'.packages.myNoctalia;
            wpctl = lib.getExe' pkgs.wireplumber "wpctl";
            brightnessctl = lib.getExe pkgs.brightnessctl;
            playerctl = lib.getExe pkgs.playerctl;
          in
          {
            spawn-at-startup = [ noctalia ];

            xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

            input = {
              keyboard.xkb = {
                layout = "de,de";
                options = "lv3:caps_switch";
              };
              touchpad = {
                tap = [ ];
                natural-scroll = [ ];
                dwt = [ ];
              };
            };

            outputs."eDP-1".scale = 1.75;

            layout = {
              gaps = 5;
              center-focused-column = "never";
            };

            binds = {
              # apps
              "Mod+Return".spawn-sh = kitty;
              "Mod+S".spawn-sh = "${noctalia} ipc call launcher toggle";
              "Mod+V".spawn-sh = "${noctalia} ipc call launcher clipboard";

              # window management
              "Mod+Q".close-window = [ ];
              "Mod+F".fullscreen-window = [ ];
              "Mod+Shift+F".maximize-column = [ ];
              "Mod+C".center-column = [ ];
              "Mod+Shift+Space".toggle-window-floating = [ ];

              # focus / move (vim-style)
              "Mod+H".focus-column-left = [ ];
              "Mod+L".focus-column-right = [ ];
              "Mod+J".focus-window-down = [ ];
              "Mod+K".focus-window-up = [ ];
              "Mod+Shift+H".move-column-left = [ ];
              "Mod+Shift+L".move-column-right = [ ];
              "Mod+Shift+J".move-window-down = [ ];
              "Mod+Shift+K".move-window-up = [ ];

              # workspaces
              "Mod+U".focus-workspace-down = [ ];
              "Mod+I".focus-workspace-up = [ ];
              "Mod+Shift+U".move-window-to-workspace-down = [ ];
              "Mod+Shift+I".move-window-to-workspace-up = [ ];

              # screenshots
              "Print".screenshot = [ ];
              "Shift+Print".screenshot-screen = [ ];
              "Mod+Print".screenshot-window = [ ];

              # media keys
              "XF86AudioRaiseVolume".spawn-sh = "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+";
              "XF86AudioLowerVolume".spawn-sh = "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
              "XF86AudioMute".spawn-sh = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
              "XF86AudioMicMute".spawn-sh = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
              "XF86MonBrightnessUp".spawn-sh = "${brightnessctl} set 5%+";
              "XF86MonBrightnessDown".spawn-sh = "${brightnessctl} set 5%-";
              "XF86AudioPlay".spawn-sh = "${playerctl} play-pause";
              "XF86AudioNext".spawn-sh = "${playerctl} next";
              "XF86AudioPrev".spawn-sh = "${playerctl} previous";

              # session
              "Mod+Shift+E".quit = [ ];
            };
          };
      };
    };
}
