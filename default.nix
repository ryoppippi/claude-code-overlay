{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkBinaryInstall makes a derivation that installs Claude Code from a binary.
  mkBinaryInstall = {
    url,
    version,
    sha256,
    actualBinaryVersion,
  }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "claude";
      src = pkgs.fetchurl {inherit url sha256;};
      nativeBuildInputs =
        [pkgs.makeWrapper]
        ++ lib.optionals pkgs.stdenv.isLinux [pkgs.autoPatchelfHook];
      buildInputs = lib.optionals pkgs.stdenv.isLinux (with pkgs; [
        stdenv.cc.cc.lib
        zlib
      ]);
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        install -m755 $src $out/bin/.claude-unwrapped

        runHook postInstall
      '';

      # Verify version and wrap binary after autoPatchelfHook (for Linux) has run
      postFixup = ''
        echo "Verifying binary version before wrapping..."

        # Check version of the raw binary (after autoPatchelfHook but before wrapping)
        version_output=$($out/bin/.claude-unwrapped --version 2>&1 || true)
        detected_version=$(echo "$version_output" | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

        if [ -z "$detected_version" ]; then
          echo "Error: Could not determine claude version from binary"
          echo "Output: $version_output"
          exit 1
        fi

        expected_version="${actualBinaryVersion}"
        if [ "$detected_version" != "$expected_version" ]; then
          echo "Error: Binary version mismatch!"
          echo "  Expected: $expected_version"
          echo "  Detected: $detected_version"
          echo "  Manifest version: ${version}"
          exit 1
        fi

        echo "✓ Version check passed: binary reports $detected_version (manifest: ${version})"

        # Now wrap the binary with environment variables
        wrapProgram $out/bin/.claude-unwrapped \
          --set DISABLE_AUTOUPDATER 1 \
          --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
          --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
          --set DISABLE_TELEMETRY 1
        mv $out/bin/.claude-unwrapped $out/bin/claude
      '';

      passthru = {
        updateScript = ./update;
      };

      meta = with lib; {
        description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
        homepage = "https://claude.ai/code";
        downloadPage = "https://github.com/anthropics/claude-code/releases";
        changelog = "https://github.com/anthropics/claude-code/releases";
        license = licenses.unfree;
        mainProgram = "claude";
        platforms = platforms.linux ++ platforms.darwin;
        maintainers = [];
      };
    };

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs
    (_: releaseData:
      mkBinaryInstall {
        inherit (releaseData.${system}) version url sha256 actualBinaryVersion;
      })
    (lib.attrsets.filterAttrs
      (_: v: (builtins.hasAttr system v) && (v.${system}.url != null) && (v.${system}.sha256 != null))
      sources);

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames taggedPackages)
  );
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  taggedPackages // {"default" = taggedPackages.${latest};}
