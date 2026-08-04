{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.goproWebcam = moduleWithSystem (
    { self', ... }:
    { config, pkgs, ... }:
    {
      environment.systemPackages = [ self'.packages.myGopro ];

      # v4l2loopback backs a persistent /dev/video42 "GoPro Webcam" device
      # that the `gopro` script feeds via ffmpeg, so apps (Discord, browsers)
      # just see it as an ordinary webcam. exclusive_caps=1 is required for
      # Chrome/Discord to recognize it as a capture-only source.
      boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
      boot.kernelModules = [ "v4l2loopback" ];
      boot.extraModprobeConfig = ''
        options v4l2loopback video_nr=42 card_label="GoPro Webcam" exclusive_caps=1
      '';

      # The camera pushes its MPEG-TS video stream to the host on this UDP
      # port unprompted -- with no prior outbound packet on that flow, the
      # default stateful firewall silently drops it as an unsolicited
      # inbound connection, leaving ffmpeg's UDP listener waiting forever.
      networking.firewall.allowedUDPPorts = [ 8554 ];
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
