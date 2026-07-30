{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  openssl,
  sqlite,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "touchstone";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "kalanik0a";
    repo = "touchstone";
    tag = "v${finalAttrs.version}";
    hash = "";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    for tool in $out/bin/ts-*; do
      wrapProgram "$tool" --prefix PATH : ${lib.makeBinPath [ openssl sqlite ]}
    done
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for tool in ts-sudo ts-ssh ts-scp ts-sftp ts-run ts-rsudo ts-audit ts-show; do
      test -x "$out/bin/$tool"
    done
    bash -n $out/lib/touchstone/touchstone-core.sh
    runHook postInstallCheck
  '';

  meta = {
    description = "Hardware-bound human consent gate for AI-agent privileged operations";
    longDescription = ''
      Touchstone routes privileged commands issued by AI coding agents
      (sudo, ssh, scp, sftp, remote sudo, interactive commands) through a
      three-pane terminal consent window where a human reviews the literal
      command and authorizes it with PAM + FIDO2 (e.g. a YubiKey touch)
      before execution. Includes an HMAC-signed audit trail, a glob-based
      policy engine (deny/warn/allow), and optional deterministic
      PreToolUse hooks for Claude Code and Codex.
    '';
    homepage = "https://github.com/kalanik0a/touchstone";
    changelog = "https://github.com/kalanik0a/touchstone/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ kalanik0a ];
    mainProgram = "ts-sudo";
  };
})
