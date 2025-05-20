# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{pkgs ? import <nixpkgs> {}}: let
  yuzuPackages = pkgs.callPackage ./pkgs/yuzuPackages {};
in {
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib {inherit pkgs;}; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  adi1090x-plymouth-themes = pkgs.callPackage ./pkgs/adi1090x-plymouth-themes {};
  example-package = pkgs.callPackage ./pkgs/example-package {};
  media-processor = import ./pkgs/media-processor {inherit pkgs;};
  prettier-with-plugins = pkgs.callPackage ./pkgs/prettier-with-plugins {};
  prettier-plugin-tailwindcss = pkgs.callPackage ./pkgs/prettier-with-plugins/prettier-plugin-tailwindcss.nix {};
  yuzu = yuzuPackages.mainline;
}
