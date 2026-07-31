{ self, inputs, ... }: {
  flake.nixosModules.systemSecrets =
    { ... }:

    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops.defaultSopsFile = ./secrets.yaml;
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets."jannik-password" = {
        neededForUsers = true;
      };

      sops.secrets."jannik-ssh-private-key" = {
        path = "/home/jannik/.ssh/id_ed25519";
        owner = "jannik";
        group = "users";
        mode = "0600";
      };

      # id_ed25519 is deployed by sops-nix above; the directory needs to exist
      # with the right ownership/mode first since ssh checks it too.
      systemd.tmpfiles.rules = [
        "d /home/jannik/.ssh 0700 jannik users -"
      ];
    };
}
