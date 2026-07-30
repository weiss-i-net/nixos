{ self, inputs, ... }: {
  flake.nixosModules.systemAudio = {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;
  };
}
