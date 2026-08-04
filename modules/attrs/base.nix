{
  moduleWithSystem,
  self,
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.base = moduleWithSystem (
    { inputs', ... }:
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        jujutsu
        neovim
        tmux
        goproWebcam
        inputs.nix-index-database.nixosModules.default
      ];
      programs.nix-index-database.comma.enable = true;

      environment.systemPackages = with pkgs; [
        git
        busybox
        fishPlugins.tide
        thunderbird
        inputs'.zen-browser.packages.default
        claude-code
        zotero
        kdePackages.okular
        wdisplays
      ];
    }
  );
}
