{pkgs, ...}: let
  # Function to get a package from a flake
  getPackageFromFlake = {
    owner,
    repo,
    rev,
    package ? "default",
  }:
    (builtins.getFlake "github:${owner}/${repo}?rev=${rev}").packages.${pkgs.stdenv.hostPlatform.system}.${package};

  mediaProcessorRev = "eb3df6fd86657690306298dfea74fd3c1702f52e";
in
  getPackageFromFlake {
    owner = "cyrilschreiber3";
    repo = "media-processor";
    rev = mediaProcessorRev;
  }
