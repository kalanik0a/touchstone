# Touchstone — NixOS module
# Hardware-bound privilege consent for AI coding agents.
#
# Usage in your NixOS config:
#   imports = [ touchstone.nixosModules.default ];
#
# Or from a local checkout:
#   imports = [ ./path/to/touchstone/module.nix ];
{
  config,
  pkgs,
  lib,
  ...
}:

let
  touchstoneLib = ./lib;

  mkTool = name: mode: extraArgs: pkgs.writeShellScriptBin name ''
    set -euo pipefail
    export TOUCHSTONE_LIB="${touchstoneLib}"
    source "${touchstoneLib}/touchstone-core.sh"
    [ $# -eq 0 ] && { echo "Usage: ${name} <command> [args...]" >&2; exit 1; }
    ts_launch_${mode} "${lib.removePrefix "ts-" name}" ${extraArgs}"$@"
  '';

  mkAuditTool = pkgs.writeShellScriptBin "ts-audit" ''
    set -euo pipefail
    _ts_find_tool() {
      local tool="$1"
      command -v "$tool" 2>/dev/null && return
      local p
      for p in /etc/profiles/per-user/*/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin; do
        [ -x "$p/$tool" ] && { echo "$p/$tool"; return; }
      done
      find /nix/store -maxdepth 3 -path "*/bin/$tool" -type f 2>/dev/null | head -1
    }
    _TS_OPENSSL="$(_ts_find_tool openssl)"
    _TS_SQLITE3="$(_ts_find_tool sqlite3)"
    export TOUCHSTONE_LIB="${touchstoneLib}"
    source "${touchstoneLib}/touchstone-backends.sh"
    source "${touchstoneLib}/touchstone-audit.sh"
    source "${touchstoneLib}/touchstone-policy.sh"
    source "${touchstoneLib}/touchstone-integrity.sh"
    _ts_load_config
    _ts_audit_init
    exec ${./bin/ts-audit} "$@"
  '';
in
{
  environment.systemPackages = [
    (mkTool "ts-sudo" "captured" "sudo ")
    (mkTool "ts-ssh"  "captured" "ssh ")
    (mkTool "ts-scp"  "captured" "scp ")
    (mkTool "ts-sftp" "captured" "sftp ")
    (mkTool "ts-run"  "interactive" "")
    mkAuditTool
    pkgs.openssl
    pkgs.sqlite
    pkgs.zenity
  ];
}
