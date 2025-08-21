# nix-headlamp

A nix Flake for packaging [headlamp.dev](https://headlamp.dev)

See [this issue](https://github.com/NixOS/nixpkgs/issues/396028) for an eventual `nixpkgs` packaging.

## Installation

Using this in your own flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-headlamp.url = "github:plaflamme/nix-headlamp"; # add this flake to your inputs
  };

  outputs = {
    nixpkgs,
    nix-headlamp,
    ...
  }:
  {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # first, apply the overlay provided by the flake
        ({ ... }: { nixpkgs.overlays = [ nix-headlamp.overlays.default ]; })

        # then you can install Headlamp wherever a package is expected, e.g:
        ({ pkgs, ... }: { environment.systemPackages = [ pkgs.headlamp ]; })
      ];
    };
  };
}
```
