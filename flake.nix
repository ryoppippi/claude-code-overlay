{
  description = "Claude Code CLI binaries.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

    forAllSystems = nixpkgs.lib.genAttrs systems;

    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude"
          ];
      };
  in {
    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      claude = pkgs.callPackage ./default.nix {};
      default = self.packages.${system}.claude;
    });

    overlays.default = _final: prev: {
      claude-code = self.packages.${prev.system}.default;
    };

    homeManagerModules.default = import ./home-module.nix self;
  };
}
