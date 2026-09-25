{
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.goproWebcam = moduleWithSystem (
    { self', ... }:
    { config, ... }:
    {
      environment.systemPackages = [ self'.packages.myGopro ];

      # A persistent /dev/video42 the `gopro` script feeds via ffmpeg, so apps
      # see an ordinary webcam. exclusive_caps=1 is what makes Chrome/Discord
      # recognize it as a capture-only source.
      boot = {
        extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
        kernelModules = [ "v4l2loopback" ];
        extraModprobeConfig = ''
          options v4l2loopback video_nr=42 card_label="GoPro Webcam" exclusive_caps=1
        '';
      };

      # The gadget's interface name otherwise varies with the USB port, leaving
      # nothing stable for the firewall rule below to name. 2672 == GoPro, the
      # same vendor id gopro.fish discovers by. Applied by udev, not networkd.
      systemd.network.links."10-gopro" = {
        matchConfig.Property = "ID_VENDOR_ID=2672";
        linkConfig.Name = "gopro0";
      };

      # The camera pushes its stream unprompted, so the stateful firewall drops
      # it as unsolicited and ffmpeg's listener waits forever. Scoped to the
      # camera's own link so the port isn't exposed on whatever wifi we're on.
      networking.firewall.interfaces."gopro0".allowedUDPPorts = [ 8554 ];
    }
  );

  perSystem =
    { pkgs, lib, ... }:
    let
      goproBin = pkgs.writers.writeFishBin "gopro" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath (
            with pkgs;
            [
              ffmpeg
              curl
              iproute2
              gnugrep
              coreutils
            ]
          ))
        ];
      } ./gopro.fish;

      goproCompletions = pkgs.runCommand "gopro-completions" { } ''
        install -Dm444 ${./completions.fish} $out/share/fish/vendor_completions.d/gopro.fish
      '';
    in
    {
      packages.myGopro = pkgs.symlinkJoin {
        name = "gopro";
        paths = [
          goproBin
          goproCompletions
        ];
        meta.mainProgram = "gopro";
      };
    };
}
