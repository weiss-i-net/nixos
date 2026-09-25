{ self, ... }: {
  flake.nixosModules.core =
    { ... }:

    {
      imports = with self.nixosModules; [
        nixSettings
      ];

      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            # Each generation pins a kernel+initrd on the small ESP until gc
            # drops it 30 days later; unbounded, a busy week fills /boot and
            # fails a switch halfway through.
            configurationLimit = 10;
          };
          efi.canTouchEfiVariables = true;
        };

        tmp.cleanOnBoot = true;
      };

      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };

      programs.fish.enable = true;

      hardware.enableRedistributableFirmware = true;

      zramSwap.enable = true;

      networking.networkmanager.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      security.rtkit.enable = true;
    };
}
