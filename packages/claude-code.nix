{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  zstd,
  alsa-lib,
  bubblewrap,
  procps,
  ripgrep,
  socat,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  manifest ? lib.importJSON ./manifest.zst.json,
}:

let
  stdenv = stdenvNoCC;
  baseUrl = "https://downloads.claude.ai/claude-code-releases";
  platformKey = "${stdenv.hostPlatform.node.platform}-${stdenv.hostPlatform.node.arch}";
  platform =
    manifest.platforms.${platformKey}
      or (throw "Unsupported Claude Code platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-code";
  inherit (manifest) version;

  src = fetchurl {
    url = "${baseUrl}/${finalAttrs.version}/${platformKey}/${platform.binary}";
    sha256 = platform.checksum;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    zstd
  ];

  strictDeps = true;
  dontUnpack = true;
  dontBuild = true;
  # The binary embeds a Bun runtime; stripping it breaks execution.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    unzstd -q "$src" -o "$out/bin/claude"
    chmod 755 "$out/bin/claude"

    runHook postInstall
  '';

  # Nix owns the install, so the self-updater and installation checks only
  # fight the store. Ripgrep and the sandbox helpers are resolved from PATH
  # instead of the binary's own vendored copies.
  postFixup = ''
    wrapProgram "$out/bin/claude" \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ alsa-lib ]} \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          procps
          ripgrep
          socat
        ]
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Agentic coding tool that lives in your terminal and understands your codebase";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://claude.com/product/claude-code";
    changelog = "https://github.com/anthropics/claude-code/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
