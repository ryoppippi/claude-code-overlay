{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "claude"
            ];
        };

        packages = rec {
          claude = pkgs.callPackage ./default.nix {};
          default = claude;
        };
      };

      flake = {
        overlays.default = _final: prev: {
          claude-code = self.packages.${prev.system}.default;
        };

        homeManagerModules.default = import ./home-module.nix self;
      };
    };
}
