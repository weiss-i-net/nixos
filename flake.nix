{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The user-facing config skeleton (lua/plugins/*.lua overrides, community.lua,
    # polish.lua) that AstroNvim's own `nix flake init -t ...neovim` template points
    # users at. Consumed directly as plain lazy-spec-shaped lua files by
    # modules/features/neovim/astronvim-bridge.lua -- not via its own init.lua/lazy,
    # since those bootstrap lazy.nvim and git-clone plugins, which we don't use.
    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };

    # AstroNvim's actual framework core. Only its lua/astronvim/plugins/*.lua spec
    # files and lua/astronvim/plugins/configs/*.lua config functions are used (by
    # the astronvim-bridge resolver); every plugin they reference comes from
    # nixpkgs.vimPlugins instead of lazy.nvim's git-clone-based installs. Pinned to
    # the same major version astronvim-template's `lazy_setup.lua` requests (^6).
    astronvim-core = {
      url = "github:AstroNvim/AstroNvim/v6.0.6";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
