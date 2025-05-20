# Import a flake from the media-processor directory using flake-compat
{pkgs, ...}: let
  mediaProcessorSrc = pkgs.fetchFromGitHub {
    owner = "cyrilschreiber3";
    repo = "media-processor";
    tag = "v0.1.0";
    hash = "sha256-TVCdir41A4zk8cR/IejfDKGhuGUCX4w1OlnWdL/Bl28=";
  };

  mediaProcessor =
    (import (pkgs.fetchFromGitHub {
        owner = "edolstra";
        repo = "flake-compat";
        rev = "9100a0f413b0c601e0533d1d94ffd501ce2e7885";
        hash = "sha256-CIVLLkVgvHYbgI2UpXvIIBJ12HWgX+fjA8Xf8PUmqCY=";
      }) {
        src = mediaProcessorSrc;
      }).defaultNix;
in
  mediaProcessor.packages.${pkgs.system}.default
