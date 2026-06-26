{
  description = "Touchstone — Hardware-bound privilege consent for AI coding agents";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./module.nix;
    nixosModules.touchstone = import ./module.nix;
  };
}
