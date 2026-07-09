# my-nixpkgs

A collection of custom Nix packages and NixOS modules.

## Installation

Add the flake as an input:
```nix
inputs.mh-pkgs = {
  url = "github:moritz-hoelting/mh-nixpkgs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then import the default NixOS module in your `nixosConfiguration`:

```nix
modules = [
    mh-pkgs.nixosModules.default
];
```

## Contained packages

- [`mensa-upb-api`](./docs/mensa-upb-api.md)