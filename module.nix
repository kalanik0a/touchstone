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
in
{
  environment.systemPackages = [
    (mkTool "ts-sudo" "captured" "sudo ")
    (mkTool "ts-ssh"  "captured" "ssh ")
    (mkTool "ts-scp"  "captured" "scp ")
    (mkTool "ts-sftp" "captured" "sftp ")
    (mkTool "ts-run"  "interactive" "")
    pkgs.zenity
  ];
}
