{ self, inputs, ... }: {
  flake.nixosModules.gaming =
    { pkgs, ... }:
    {
      programs.steam.enable = true;
      programs.gamemode.enable = true;
      programs.gamescope.enable = true;

      # amdgpu's default "auto" fan/power behavior runs noticeably hotter and
      # louder under load than AMD's Windows driver. LACT gives a GUI+daemon
      # to set a custom fan curve/power limit (like Adrenalin does on
      # Windows) that persists across reboots.
      services.lact.enable = true;

      # LACT can only do fan/power limit control without this; overdrive
      # mode is what unlocks clock/voltage curve tuning (amdgpu's
      # equivalent of Adrenalin's "Overdrive" tab).
      hardware.amdgpu.overdrive.enable = true;

      users.users."jannik".packages = [ pkgs.discord ];
    };
}
