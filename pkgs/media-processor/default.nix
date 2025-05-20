{pkgs, ...}: let
  # Function to get a package from a flake
  getPackageFromFlake = {
    owner,
    repo,
    rev,
    package ? "default",
  }:
    (builtins.getFlake "github:${owner}/${repo}?rev=${rev}").packages.${pkgs.system}.${package};

  mediaProcessorRev = "1bd397ff3fdb821a29dc3675e19da32b0c686994";
in
  getPackageFromFlake {
    owner = "cyrilschreiber3";
    repo = "media-processor";
    rev = mediaProcessorRev;
  }
