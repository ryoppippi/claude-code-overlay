{
  pkgs,
  additionalPaths ? [],
  ...
}:
pkgs.callPackage ./package.nix {inherit additionalPaths;}
