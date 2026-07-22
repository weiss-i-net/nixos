{ self, inputs, ... }: {

  perSystem = { pkgs, ... }: {
    packages.myNeovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      runtimePkgs = with pkgs; [
        stdenv
        ripgrep
        fd
        lazygit
        nodejs
        python3
        gcc
        tree-sitter
        cargo
      ];
    };

  };
}
