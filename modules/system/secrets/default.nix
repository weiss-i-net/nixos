{ self, inputs, ... }: {
  flake.nixosModules.secrets =
    { ... }:

    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      # Only the sops-nix wiring lives here -- which secrets a host wants
      # decrypted is the concern of whatever declares them (user.nix for
      # jannik's, the host configuration for per-machine ones).
      sops = {
        defaultSopsFile = ./secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/key.txt";
      };
    };
}
