{
  description = "A flake for building yuzuPackages with qt6";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      yuzuPackages = pkgs.callPackage ./default.nix {};
    in {
      packages = {
        default = yuzuPackages.mainline;
        compat-list = yuzuPackages.compat-list;
        nx_tzdb = yuzuPackages.nx_tzdb;
      };
    });
}
