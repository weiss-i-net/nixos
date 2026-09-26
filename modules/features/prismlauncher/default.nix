{
  moduleWithSystem,
  ...
}:
# No wrapper-modules wrap here: the point isn't generating config, it's patching
# out upstream's check that an offline account requires a Microsoft one.
{
  flake.nixosModules.prismlauncher = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = [ self'.packages.myPrismlauncher ];
    }
  );

  perSystem =
    { pkgs, ... }:
    {
      packages.myPrismlauncher =
        (pkgs.prismlauncher.override {

          prismlauncher-unwrapped = pkgs.prismlauncher-unwrapped.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./prism_disable_account.patch
            ];
          });
        }).overrideAttrs
          (old: {
            # niri speaks no fifo-v1, so SDL falls back to XWayland and resolves GL
            # through GLX, while LWJGL goes by XDG_SESSION_TYPE and hands it libEGL.
            # Minecraft's OpenGL backend then fails to load and it quietly drops to
            # Vulkan, which Iris cannot render on and aborts the JVM.
            qtWrapperArgs = old.qtWrapperArgs ++ [ "--set-default SDL_VIDEO_DRIVER wayland" ];
          });
    };

}
