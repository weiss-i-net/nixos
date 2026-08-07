{
  moduleWithSystem,
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.base = moduleWithSystem (
    { inputs', ... }:
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        kitty
        goproWebcam
        inputs.nix-index-database.nixosModules.default
      ];
      programs.nix-index-database.comma.enable = true;

      environment.systemPackages = with pkgs; [
        busybox
        fishPlugins.tide
        thunderbird
        inputs'.zen-browser.packages.default
        zotero
        kdePackages.okular
        wdisplays
      ];
    }
  );
}
