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
            ps = lib.getExe' pkgs.procps "ps";
            readlink = lib.getExe' pkgs.coreutils "readlink";

            # niri has no "spawn in the focused window's directory" action, so
            # derive it: ask niri for the focused window's pid, find the program
            # running in the foreground of that terminal, and read its cwd. Only
            # done for kitty windows -- any other app's cwd is meaningless as a
            # terminal starting point.
            kittyInCwd = pkgs.writeShellScript "kitty-in-cwd" ''
              set -u

              dir=""
              window=$(${lib.getExe' pkgs.niri "niri"} msg --json focused-window 2>/dev/null) || window=""

              if [ -n "$window" ]; then
                app=$(${lib.getExe pkgs.jq} -r '.app_id // ""' <<<"$window")
                pid=$(${lib.getExe pkgs.jq} -r '.pid // 0' <<<"$window")

                if [ "$app" = kitty ] && [ "$pid" -gt 0 ]; then
                  # kitty's own cwd is useless (it never follows the shell), and so is
                  # simply descending to its newest child -- kitty keeps ttyless
                  # "kitten" helpers sitting in $HOME alongside the shell. The shell is
                  # the child that owns a pty, so pick that one.
                  shell=""
                  tty=""
                  while read -r childPid childTty; do
                    if [ "$childTty" != "?" ]; then
                      shell=$childPid
                      tty=$childTty
                      break
                    fi
                  done < <(${ps} -o pid=,tty= --ppid "$pid")

                  if [ -n "$shell" ]; then
                    # Everything in that pty's foreground process group carries "+" in
                    # its state, so the last such pid is the innermost thing the user is
                    # looking at (a nested shell, an editor); with an idle prompt it is
                    # the shell itself. Its cwd is what "same folder" means.
                    target=$shell
                    while read -r ttyPid ttyStat; do
                      case $ttyStat in
                        *+*) target=$ttyPid ;;
                      esac
                    done < <(${ps} -o pid=,stat= -t "$tty")

                    cwd=$(${readlink} -e "/proc/$target/cwd") || cwd=""
                    [ -n "$cwd" ] && dir=$cwd
                  fi
                fi
              fi

              if [ -n "$dir" ]; then
                exec ${kitty} --directory "$dir"
              else
                exec ${kitty}
              fi
            '';
          in
          {
            spawn-at-startup = [ noctalia ];

            xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

            # Matches XCURSOR_* in system/desktop.nix; without an explicit theme
            # niri falls back to an oversized placeholder.
            cursor = {
              xcursor-theme = "Adwaita";
              xcursor-size = 24;
            };

            input = {
              keyboard.xkb = {
                layout = "de";
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

            # A bind matches the physical key's *unshifted* keysym plus the
            # modifiers literally held -- it does not resolve to the shifted
            # character. On the German layout that makes the punctuation binds
            # below look wrong: "/" is Shift+7, "+" has its own key (so never
            # Equal), and "["/"]" are AltGr (Mod5) on 8/9.
            binds = {
              # apps
              "Mod+Return".spawn-sh = "${kittyInCwd}";
              "Mod+S".spawn-sh = "${noctalia} msg panel-toggle launcher";
              "Mod+V".spawn-sh = "${noctalia} msg panel-toggle clipboard";

              # help / overview
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
              "Mod+Minus".set-column-width = "-10%";
              "Mod+Plus".set-column-width = "+10%";
              "Mod+Shift+Minus".set-window-height = "-10%";
              "Mod+Shift+Plus".set-window-height = "+10%";
              "Mod+Shift+Space".toggle-window-floating = [ ];
              "Mod+Shift+V".switch-focus-between-floating-and-tiling = [ ];
              "Mod+W".toggle-column-tabbed-display = [ ];
              "Mod+Mod5+8".consume-or-expel-window-left = [ ];
              "Mod+Mod5+9".consume-or-expel-window-right = [ ];
              "Mod+Comma".consume-window-into-column = [ ];
              "Mod+Period".expel-window-from-column = [ ];

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

              # monitor focus / move -- Ctrl tier, since Shift already moves columns
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
