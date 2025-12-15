self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.claude-code;
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.programs.claude-code = {
    enableLocalBinSymlink = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isLinux;
      description = ''
        Whether to create a symlink at ~/.local/bin/claude.
        Enabled by default on Linux to avoid "claude command not found" warnings.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code.package = lib.mkDefault (
      if cfg.enableLocalBinSymlink
      then (package.override {additionalPaths = ["${config.home.homeDirectory}/.local/bin"];})
      else package
    );

    # Create symlink to ~/.local/bin/claude (enabled by default on Linux)
    home.file.".local/bin/claude" = lib.mkIf cfg.enableLocalBinSymlink {
      source = "${cfg.package}/bin/claude";
    };
  };
}
