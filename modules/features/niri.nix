{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.niri = moduleWithSystem (
    { self', ... }:
    { lib, ... }: {
      programs.niri = {
        enable = true;
        package = lib.mkDefault self'.packages.myNiri;
      };
      systemd.user.services.niri.enableDefaultPath = false;
    }
  );

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

            # Matches environment.variables.XCURSOR_THEME/SIZE in common.nix --
            # without an explicit theme, niri falls back to an oversized
            # built-in placeholder cursor.
            cursor = {
              xcursor-theme = "Adwaita";
              xcursor-size = 24;
            };

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

            layout = {
              gaps = 5;
              center-focused-column = "never";
            };

            window-rules = [
              {
                matches = [ { app-id = "^zen"; } ];
                default-column-width.proportion = 0.666667;
              }
            ];

            binds = {
              # apps
              "Mod+Return".spawn-sh = kitty;
              "Mod+S".spawn-sh = "${noctalia} msg panel-toggle launcher";
              "Mod+V".spawn-sh = "${noctalia} msg panel-toggle clipboard";

              # help / overview
              # niri binds always match a physical key's *unshifted* keysym plus whatever
              # modifiers are literally held (it does not resolve to the shifted character).
              # "/" only exists as Shift+7 on the German layout (there's no key whose unshifted
              # symbol is "/"), so the bind must name the base key ("7"), not "Slash".
              "Mod+Shift+7".show-hotkey-overlay = [ ];
              "Mod+O".toggle-overview = [ ];

              # window management
              "Mod+Q".close-window = [ ];
              "Mod+F".fullscreen-window = [ ];
              "Mod+Shift+F".maximize-column = [ ];
              "Mod+M".maximize-window-to-edges = [ ];
              "Mod+C".center-column = [ ];
              "Mod+Ctrl+C".center-visible-columns = [ ];
              "Mod+Ctrl+F".expand-column-to-available-width = [ ];
              "Mod+R".switch-preset-column-width = [ ];
              "Mod+Shift+R".switch-preset-column-width-back = [ ];
              "Mod+Ctrl+R".reset-window-height = [ ];
              "Mod+Ctrl+Shift+R".switch-preset-window-height = [ ];
              "Mod+Minus".set-column-width = "-10%"; # unshifted "-" key, same on German and US layouts
              # "=" doesn't exist as an unshifted symbol anywhere on the German layout (it's
              # Shift+0, and Equal's *base* symbol there is "0", not "="), so "Mod+Equal" would
              # never match. Its own dedicated "+"/"*" key is unshifted "+" on German, so bind
              # to that instead -- same key for both width (no Shift) and height (Shift) below.
              "Mod+Plus".set-column-width = "+10%";
              "Mod+Shift+Minus".set-window-height = "-10%";
              "Mod+Shift+Plus".set-window-height = "+10%";
              "Mod+Shift+Space".toggle-window-floating = [ ];
              "Mod+Shift+V".switch-focus-between-floating-and-tiling = [ ];
              "Mod+W".toggle-column-tabbed-display = [ ];
              # Same base-keysym rule as above: "[" is AltGr+8 on German, i.e. base key "8" with
              # the ISO_Level3_Shift (AltGr) modifier held -- "Mod+BracketLeft" would never fire.
              "Mod+Mod5+8".consume-or-expel-window-left = [ ];
              "Mod+Mod5+9".consume-or-expel-window-right = [ ];
              "Mod+Comma".consume-window-into-column = [ ]; # "," is unshifted on German layout too, same key as US
              "Mod+Period".expel-window-from-column = [ ]; # same for "."

              # focus / move (vim-style, mirrored on arrow keys)
              "Mod+H".focus-column-left = [ ];
              "Mod+L".focus-column-right = [ ];
              "Mod+J".focus-window-down = [ ];
              "Mod+K".focus-window-up = [ ];
              "Mod+Left".focus-column-left = [ ];
              "Mod+Right".focus-column-right = [ ];
              "Mod+Down".focus-window-down = [ ];
              "Mod+Up".focus-window-up = [ ];
              "Mod+Shift+H".move-column-left = [ ];
              "Mod+Shift+L".move-column-right = [ ];
              "Mod+Shift+J".move-window-down = [ ];
              "Mod+Shift+K".move-window-up = [ ];
              "Mod+Shift+Left".move-column-left = [ ];
              "Mod+Shift+Right".move-column-right = [ ];
              "Mod+Shift+Down".move-window-down = [ ];
              "Mod+Shift+Up".move-window-up = [ ];
              "Mod+Home".focus-column-first = [ ];
              "Mod+End".focus-column-last = [ ];
              "Mod+Ctrl+Home".move-column-to-first = [ ];
              "Mod+Ctrl+End".move-column-to-last = [ ];

              # monitor focus / move (Ctrl tier, since Shift above already moves columns/windows;
              # only useful once a second output is configured, but harmless to have ready)
              "Mod+Ctrl+H".focus-monitor-left = [ ];
              "Mod+Ctrl+L".focus-monitor-right = [ ];
              "Mod+Ctrl+J".focus-monitor-down = [ ];
              "Mod+Ctrl+K".focus-monitor-up = [ ];
              "Mod+Ctrl+Left".focus-monitor-left = [ ];
              "Mod+Ctrl+Right".focus-monitor-right = [ ];
              "Mod+Ctrl+Down".focus-monitor-down = [ ];
              "Mod+Ctrl+Up".focus-monitor-up = [ ];
              "Mod+Ctrl+Shift+H".move-column-to-monitor-left = [ ];
              "Mod+Ctrl+Shift+L".move-column-to-monitor-right = [ ];
              "Mod+Ctrl+Shift+J".move-column-to-monitor-down = [ ];
              "Mod+Ctrl+Shift+K".move-column-to-monitor-up = [ ];
              "Mod+Ctrl+Shift+Left".move-column-to-monitor-left = [ ];
              "Mod+Ctrl+Shift+Right".move-column-to-monitor-right = [ ];
              "Mod+Ctrl+Shift+Down".move-column-to-monitor-down = [ ];
              "Mod+Ctrl+Shift+Up".move-column-to-monitor-up = [ ];

              # workspaces
              "Mod+U".focus-workspace-down = [ ];
              "Mod+I".focus-workspace-up = [ ];
              "Mod+Shift+U".move-window-to-workspace-down = [ ];
              "Mod+Shift+I".move-window-to-workspace-up = [ ];
              "Mod+1".focus-workspace = 1;
              "Mod+2".focus-workspace = 2;
              "Mod+3".focus-workspace = 3;
              "Mod+4".focus-workspace = 4;
              "Mod+5".focus-workspace = 5;
              "Mod+6".focus-workspace = 6;
              "Mod+7".focus-workspace = 7;
              "Mod+8".focus-workspace = 8;
              "Mod+9".focus-workspace = 9;
              "Mod+Ctrl+1".move-window-to-workspace = 1;
              "Mod+Ctrl+2".move-window-to-workspace = 2;
              "Mod+Ctrl+3".move-window-to-workspace = 3;
              "Mod+Ctrl+4".move-window-to-workspace = 4;
              "Mod+Ctrl+5".move-window-to-workspace = 5;
              "Mod+Ctrl+6".move-window-to-workspace = 6;
              "Mod+Ctrl+7".move-window-to-workspace = 7;
              "Mod+Ctrl+8".move-window-to-workspace = 8;
              "Mod+Ctrl+9".move-window-to-workspace = 9;

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
              "Ctrl+Alt+Delete".quit = [ ]; # backup in case Mod is unavailable (e.g. stuck key)
              "Mod+Shift+P".power-off-monitors = [ ];
              "Mod+Escape" = _: {
                props.allow-inhibiting = false;
                content.toggle-keyboard-shortcuts-inhibit = _: { };
              };
            };
          };

      };
    };
}
