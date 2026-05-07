{
  description = "A flake for packaing headlamp.dev as a k8s desktop client";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    builtins.trace
      "WARNING: the nix-headlamp flake is deprecated. Use the package from nixpkgs directly instead."
      {

        overlays.default = final: prev: {
          headlamp = (prev.callPackage ./default.nix) { };
        };

        packages = forAllSystems (
          system:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          {
            default = (pkgs.callPackage ./default.nix) { };
          }
        );
      };
}
