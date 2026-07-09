{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    mensa-upb-api = {
      url = "github:moritz-hoelting/mensa-upb-api";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      packagesFromInputs = import ./lib/packages-from-inputs.nix {
        inherit flake-utils;
        inherit inputs;
      };
    in
    {
      inherit (packagesFromInputs [ "mensa-upb-api" ]) packages;

      nixosModules = rec {
        default = {
          imports = [
            mensa-upb-api
          ];
        };

        mensa-upb-api = import ./modules/mensa-upb-api.nix {
          inherit (self) packages;
        };
      };
    };
}
