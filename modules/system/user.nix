{ self, ... }: {
  flake.nixosModules.user =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = with self.nixosModules; [
        homeManager
        secrets
      ];

      # The password lives in sops (hashedPasswordFile below), so let the
      # config be authoritative: an out-of-band `passwd` would otherwise
      # persist and drift the machine away from what's declared here.
      # Note this leaves root without a password -- recovery is via the boot
      # menu (init=/bin/sh) or an installer ISO.
      users.mutableUsers = false;

      users.users."jannik" = {
        uid = 1000;
        isNormalUser = true;
        description = "Jannik Hiller";
        shell = pkgs.fish;
        hashedPasswordFile = config.sops.secrets."jannik-password".path;
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
        ]
        # The group only exists when attrs/gaming is imported; listing it
        # unconditionally breaks activation on a host without that bundle.
        ++ lib.optional config.programs.gamemode.enable "gamemode";
      };

      home-manager.users.jannik = {
        home.stateVersion = config.system.stateVersion;
        programs.home-manager.enable = true;
      };

      sops.secrets = {
        "jannik-password" = {
          neededForUsers = true;
        };

        "jannik-ssh-private-key" = {
          path = "/home/jannik/.ssh/id_ed25519";
          owner = "jannik";
          group = "users";
          mode = "0600";
        };
      };

      # id_ed25519 is deployed by sops-nix above; the directory needs to exist
      # with the right ownership/mode first since ssh checks it too.
      systemd.tmpfiles.rules = [
        "d /home/jannik/.ssh 0700 jannik users -"
      ];
    };
}
