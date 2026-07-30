{
  description = "Touchstone — Hardware-bound privilege consent for AI coding agents";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules.default = import ./module.nix;
      nixosModules.touchstone = import ./module.nix;

      packages = forAllSystems (pkgs: rec {
        touchstone = (pkgs.callPackage ./package.nix { }).overrideAttrs {
          # Build from the flake's own tree; the fetchFromGitHub src in
          # package.nix is for the standalone/nixpkgs consumption path.
          src = self;
        };
        default = touchstone;
      });
    };
}
