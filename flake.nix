{
  description = "A flake for packaing headlamp.dev as a k8s desktop client";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
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
