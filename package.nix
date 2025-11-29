{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  zlib,
  writableTmpDirAsHomeHook,
  versionCheckHook,
  additionalPaths ? [],
}: let
  sourcesData = lib.importJSON ./sources.json;
  inherit (sourcesData) version;
  sources = sourcesData.platforms;

  source =
    sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  additionalOptions =
    lib.optionalString (additionalPaths != [])
    "--prefix PATH : ${builtins.concatStringsSep ":" additionalPaths}";
in
  stdenv.mkDerivation rec {
    pname = "claude";
    inherit version;

    src = fetchurl {
      inherit (source) url hash;
    };

    nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.isLinux [autoPatchelfHook];

    buildInputs = lib.optionals stdenv.isLinux [
      stdenv.cc.cc.lib
      zlib
    ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 $src $out/bin/claude

      runHook postInstall
    '';

    # Wrap the binary with environment variables to disable telemetry and auto-updates
    postFixup = ''
      wrapProgram $out/bin/claude ${additionalOptions} \
        --set DISABLE_AUTOUPDATER 1 \
        --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
        --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
        --set DISABLE_TELEMETRY 1
    '';

    dontStrip = true; # to not mess with the bun runtime

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      writableTmpDirAsHomeHook
      versionCheckHook
    ];
    versionCheckKeepEnvironment = ["HOME"];
    versionCheckProgramArg = "--version";

    passthru = {
      updateScript = ./update.ts;
    };

    meta = with lib; {
      inherit version;
      description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
      homepage = "https://claude.ai/code";
      downloadPage = "https://github.com/anthropics/claude-code/releases";
      changelog = "https://github.com/anthropics/claude-code/releases";
      license = licenses.unfree;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "claude";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      maintainers = [];
    };
  }
