{ self, ... }:
{
  flake.nixosModules.remoteBuild =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.remoteBuild;

      # Both halves of this module refer to the same keypair -- the builder
      # authorizes this public key, the client's nix-daemon authenticates with
      # the private half out of sops -- so it lives here rather than being
      # duplicated into each host's configuration.
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3XazhBVJSxyiDfER3FjpFFt+fIYXOxz1fuF0cm0Hr8 nixremote";
    in
    {
      imports = with self.nixosModules; [
        secrets
      ];

      options.remoteBuild = {
        server.enable = lib.mkEnableOption "accepting nix builds offloaded over ssh by the nixremote user";

        client = {
          enable = lib.mkEnableOption "offloading nix builds to a remote builder";
          hostName = lib.mkOption {
            type = lib.types.str;
            description = "Address of the remote builder.";
          };
          hostKey = lib.mkOption {
            type = lib.types.str;
            description = "The builder's ssh host public key, pinned in the system known_hosts.";
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.server.enable {
          services.openssh = {
            enable = true;
            settings = {
              # nixremote is the only account reachable over ssh and it
              # authenticates by key, so nothing here needs a password prompt.
              PasswordAuthentication = false;
              PermitRootLogin = "no";
            };
          };

          users.groups.nixremote = { };

          users.users."nixremote" = {
            isSystemUser = true;
            group = "nixremote";
            # nix reaches the builder by running `nix-daemon --stdio` through
            # this account's login shell -- a nologin shell would leave ssh
            # working while every offloaded build fails.
            shell = pkgs.bashInteractive;
            openssh.authorizedKeys.keys = [ publicKey ];
          };

          # The closures a client uploads are unsigned; without this the daemon
          # refuses them and every offloaded build dies on a missing signature.
          nix.settings.trusted-users = [ "nixremote" ];
        })

        (lib.mkIf cfg.client.enable {
          nix = {
            distributedBuilds = true;

            buildMachines = [
              {
                inherit (cfg.client) hostName;
                sshUser = "nixremote";
                sshKey = config.sops.secrets."nixremote-ssh-private-key".path;
                systems = [ "x86_64-linux" ];
                protocol = "ssh-ng";
                maxJobs = 8;
                # Anything above 1 makes nix prefer the builder over this
                # host's own slot, which is the whole point of the offload.
                speedFactor = 4;
                supportedFeatures = [
                  "nixos-test"
                  "benchmark"
                  "big-parallel"
                  "kvm"
                ];
              }
            ];

            # Let the builder fetch substitutes itself instead of pulling them
            # down here and pushing them back up over the same link.
            settings.builders-use-substitutes = true;
          };

          # Read by the nix-daemon as root, so sops-nix's root:root 0400
          # default under /run/secrets is exactly what's wanted.
          sops.secrets."nixremote-ssh-private-key" = { };

          # The daemon connects non-interactively, so an unknown host key is a
          # hard failure rather than a prompt.
          programs.ssh.knownHosts.${cfg.client.hostName}.publicKey = cfg.client.hostKey;
        })
      ];
    };
}
