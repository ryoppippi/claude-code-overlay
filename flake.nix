{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Git hooks
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Treefmt for formatting
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    git-hooks,
    treefmt-nix,
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

      # Treefmt configuration
      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
        };
      };
    in rec {
      # Git hooks configuration
      checks = {
        git-hooks-check = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };
        };
        formatting = treefmtEval.config.build.check self;
      };

      # The packages exported by the Flake:
      packages = rec {
        claude = pkgs.callPackage ./default.nix {};
        default = claude;
      };

      # "Apps" so that `nix run` works. If you run `nix run .` then
      # this will use the latest default.
      apps = rec {
        default = apps.claude;
        claude = flake-utils.lib.mkApp {drv = packages.default;};
        fmt = flake-utils.lib.mkApp {drv = treefmtEval.config.build.wrapper;};
      };

      # nix fmt
      formatter = treefmtEval.config.build.wrapper;

      devShells.default = pkgs.mkShell {
        inherit (self.checks.${system}.git-hooks-check) shellHook;
        nativeBuildInputs = with pkgs; [
          curl
          jq
        ];
      };
    });
  in
    outputs
    // {
      # Overlay that provides claude-code package
      overlays.default = _final: prev: {
        claude-code = outputs.packages.${prev.system}.default;
      };
    };
}
