{ inputs, ... }: {
  flake.nixosModules.secrets =
    { ... }:

    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      # Wiring only; which secrets get decrypted is declared by whoever needs them.
      sops = {
        defaultSopsFile = ./secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/key.txt";
      };
    };
}
