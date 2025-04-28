# originally from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ad/adi1090x-plymouth-themes/package.nix
{
  stdenv,
  fetchFromGitHub,
  fetchurl,
  lib,
  unzip,
  # To select only certain themes, pass `selected_themes` as a list of strings.
  # reference ./shas.nix for available themes
  selected_themes ? [],
  display_nixos_logo ? false,
}: let
  version = "1.0";
  # this file is generated via ./update.sh
  # borrowed from pkgs/data/fonts/nerdfonts
  themeShas = import ./shas.nix;
  knownThemes = builtins.attrNames themeShas;
  selectedThemes =
    if (selected_themes == [])
    then knownThemes
    else let
      unknown = lib.subtractLists knownThemes selected_themes;
    in
      if (unknown != [])
      then throw "Unknown theme(s): ${lib.concatStringsSep " " unknown}"
      else selected_themes;
  srcs = lib.lists.forEach selectedThemes (
    name: (fetchurl {
      url = themeShas.${name}.url;
      sha256 = themeShas.${name}.sha;
    })
  );

  display_nixos_logo_str =
    if display_nixos_logo
    then "true"
    else "false";

  nix-artwork =
    if display_nixos_logo
    then
      fetchFromGitHub {
        owner = "NixOS";
        repo = "nixos-artwork";
        rev = "de03e887f03037e7e781a678b57fdae603c9ca20";
        hash = "sha256-78FyNyGtDZogJUWcCT6A/T2MK87nGN/muC7ANH1b1V8=";
      }
    else "";
in
  stdenv.mkDerivation {
    pname = "adi1090x-plymouth-themes";
    inherit version srcs;

    nativeBuildInputs = [
      unzip
    ];

    sourceRoot = ".";
    unpackCmd = ''
      if [[ $curSrc != *'-source' ]]; then
        tar xzf $curSrc
      fi
    '';

    installPhase = ''
      mkdir -p $out/share/plymouth/themes
      for theme in ${toString selectedThemes}; do
        echo "Installing $theme"
        mv $theme $out/share/plymouth/themes/$theme

        if ${display_nixos_logo_str}; then
          echo "Adding NixOS logo to $theme"
          cp ${nix-artwork}/logo/nixos-white.png $out/share/plymouth/themes/$theme/nixos-logo.png
          find $out/share/plymouth/themes/$theme -name \*.script -exec sed -i '$a\
      # display nixos logo\
      nixos_image = Image("nixos-logo.png"); # change filename accordingly\
      nixos_image.SetScale(0.1); # scale the image to 10% of its original size\
      nixos_sprite = Sprite();\
      nixos_sprite.SetImage(nixos_image);\
      nixos_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - nixos_image.GetWidth() / 2)); # center the image horizontally\
      nixos_sprite.SetY(Window.GetHeight() - nixos_image.GetHeight() - 50); # display just above the bottom of the screen\
      ' {} \;
        fi
      done
      find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    '';

    meta = with lib; {
      description = "Plymouth boot themes from adi1090x";
      longDescription = ''
        A variety of plymouth boot screens by adi1090x.  Using the default value
        of `selected_themes` will install all themes (~524M).  Consider overriding
        this with a list of the string names of each theme to install.  Check
        ./shas.nix for available themes.
      '';
      homepage = "https://github.com/adi1090x/plymouth-themes";
      license = licenses.gpl3;
      platforms = platforms.linux;
      maintainers = with maintainers; [slwst];
    };
  }
