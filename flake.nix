{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      treefmt-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    flake-parts.lib.mkFlake { inherit self; } {
      inherit systems;

      imports = [
        treefmt-nix.flakeModule
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          pkgsFor = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "claude"
              ];
          };
        in
        {
          packages = {
            claude = pkgsFor.callPackage ./default.nix { };
            default = self.packages.${system}.claude;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            settings = {
              global.excludes = [
                ".git/**"
                "*.lock"
                "*.nix"
              ];
              formatter = {
                oxfmt = {
                  command = "${pkgs.oxfmt}/bin/oxfmt";
                  options = [ "--no-error-on-unmatched-pattern" ];
                  includes = [ "*" ];
                };
              };
            };
          };
        };

      flake = {
        overlays.default = _final: prev: {
          claude-code = self.packages.${prev.system}.default;
        };
      };
    };
}
