# Import a flake from the media-processor directory using flake-compat
{pkgs, ...}: let
  mediaProcessorSrc = pkgs.fetchFromGitHub {
    owner = "cyrilschreiber3";
    repo = "media-processor";
    tag = "v0.1.0";
    hash = "sha256-TVCdir41A4zk8cR/IejfDKGhuGUCX4w1OlnWdL/Bl28=";
  };

  flake-compat = fetchTarball {
    url = "https://github.com/nix-community/flake-compat/archive/0f158086a2ecdbb138cd0429410e44994f1b7e4b.tar.gz";
    sha256 = "sha256-5SSSZ/oQkwfcAz/o/6TlejlVGqeK08wyREBQ5qFFPhM=";
  };

  mediaProcessor = import flake-compat {
    src = mediaProcessorSrc;
  };
in
  mediaProcessor.defaultNix.packages.${pkgs.system}.default
