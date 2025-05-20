# Import a flake from the media-processor directory using flake-compat
{pkgs, ...}: let
  mediaProcessorSrc = pkgs.fetchFromGitHub {
    owner = "cyrilschreiber3";
    repo = "media-processor";
    tag = "v0.1.0";
    hash = "sha256-TVCdir41A4zk8cR/IejfDKGhuGUCX4w1OlnWdL/Bl28=";
  };
  mediaProcessorLock = builtins.fromJSON (builtins.readFile "${mediaProcessorSrc}/flake.lock");
  root = mediaProcessorLock.nodes.${mediaProcessorLock.root};
  inherit (mediaProcessorLock.nodes.${root.inputs.gomod2nix}.locked) owner repo rev narHash;

  gomod2nixSrc = pkgs.fetchFromGitHub {
    owner = owner;
    repo = repo;
    rev = rev;
    hash = narHash;
  };

  pkgsWithOverlay = import pkgs.path {
    inherit (pkgs) system;
    overlays = [
      (import "${gomod2nixSrc}/overlay.nix")
    ];
  };
in
  pkgsWithOverlay.callPackage "${mediaProcessorSrc}/default.nix" {}
