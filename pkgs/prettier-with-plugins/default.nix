{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  nodePackages,
  plugins ? [],
  prettier-plugin-go-template,
}: let
  prettier = nodePackages.prettier;
in
  stdenv.mkDerivation {
    pname = "prettier-with-plugins";
    version = "3.5.3";

    src = prettier;

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/lib/node_modules

      ln -s ${prettier}/bin/prettier $out/bin/prettier
      ln -s ${prettier}/lib/node_modules/prettier $out/lib/node_modules/prettier

      # Symlink plugins to the lib/node_modules directory dynamically based on the plugins attribute
      ${lib.concatMapStringsSep "\n" (plugin: ''
          ln -s ${plugin}/lib/node_modules/${plugin.pname} $out/lib/node_modules/${plugin.pname}
        '')
        plugins}
    '';

    meta = {
      description = "An opinionated code formatter";
      mainProgram = "prettier";
      homepage = "https://prettier.io";
    };
  }
