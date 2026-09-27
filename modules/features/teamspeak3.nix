{
  inputs,
  moduleWithSystem,
  ...
}:
# No wrapper-modules wrap here: nothing to configure from nix, the client keeps
# its own settings. It comes from a pinned nixpkgs because current nixpkgs
# removed teamspeak3 along with the EOL qt5 webengine it links against. The pin
# is the last revision whose qtwebengine-5.15.19 hydra built: move it forward and
# that drv stops substituting, leaving a chromium compile that OOMs this machine.
{
  flake.nixosModules.teamspeak3 = moduleWithSystem (
    { self', ... }:
    {
      environment.systemPackages = [ self'.packages.myTeamspeak3 ];
    }
  );

  perSystem =
    { system, ... }:
    {
      packages.myTeamspeak3 =
        (import inputs.nixpkgs-teamspeak3 {
          inherit system;
          config.allowUnfree = true;
        }).teamspeak3.overrideAttrs
          (old: {
            # Upstream pins the client to xcb. Its qt 5.15 cannot find a GLX
            # FBConfig through xwayland-satellite -- qtwebengine then aborts
            # with "Could not initialize GLX" -- while the session's own GLX is
            # fine. The bundled qtwayland plugin starts it without any of that.
            qtWrapperArgs = map (
              arg: if arg == "--set QT_QPA_PLATFORM xcb" then "--set QT_QPA_PLATFORM wayland" else arg
            ) old.qtWrapperArgs;
          });
    };
}
