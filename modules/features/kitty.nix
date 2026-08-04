{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.kitty = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = [ self'.packages.myKitty ];
    }
  );

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.myKitty = inputs.wrapper-modules.wrappers.kitty.wrap {
        inherit pkgs;
        settings = {
          font_family = "JetBrainsMono Nerd Font";
          font_size = 11;
          bold_font = "auto";
          italic_font = "auto";

          window_padding_width = 8;
          confirm_os_window_close = 0;
          enable_audio_bell = false;
          cursor_shape = "beam";
          cursor_blink_interval = 0;

          scrollback_lines = 10000;
          shell_integration = "enabled";

          tab_bar_style = "hidden";
          hide_window_decorations = "yes";

          # base16-default-dark (Chris Kempson, http://chriskempson.com)
          background = "#181818";
          foreground = "#d8d8d8";
          selection_background = "#d8d8d8";
          selection_foreground = "#181818";
          url_color = "#b8b8b8";
          cursor = "#d8d8d8";
          active_border_color = "#585858";
          inactive_border_color = "#282828";
          active_tab_background = "#181818";
          active_tab_foreground = "#d8d8d8";
          inactive_tab_background = "#282828";
          inactive_tab_foreground = "#b8b8b8";
          tab_bar_background = "#282828";

          color0 = "#181818";
          color1 = "#ab4642";
          color2 = "#a1b56c";
          color3 = "#f7ca88";
          color4 = "#7cafc2";
          color5 = "#ba8baf";
          color6 = "#86c1b9";
          color7 = "#d8d8d8";
          color8 = "#585858";
          color9 = "#ab4642";
          color10 = "#a1b56c";
          color11 = "#f7ca88";
          color12 = "#7cafc2";
          color13 = "#ba8baf";
          color14 = "#86c1b9";
          color15 = "#f8f8f8";

          # base16 256-color extension (base09, base0F, base01, base02, base04, base06)
          color16 = "#dc9656";
          color17 = "#a16946";
          color18 = "#282828";
          color19 = "#383838";
          color20 = "#b8b8b8";
          color21 = "#e8e8e8";
        };

      };

    };

}
