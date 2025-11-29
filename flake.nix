{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude"
          ];
      };
    in {
      packages = rec {
        claude = pkgs.callPackage ./default.nix {};
        default = claude;
      };
    });
  in
    outputs
    // {
      overlays.default = _final: prev: {
        claude-code = outputs.packages.${prev.system}.default;
      };

      homeManagerModules.default = import ./home-module.nix outputs;
    };
}
