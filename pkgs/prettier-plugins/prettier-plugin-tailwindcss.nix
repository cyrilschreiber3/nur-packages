{
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "prettier-plugin-tailwindcss";
  version = "0.6.11";

  src = fetchFromGitHub {
    owner = "tailwindlabs";
    repo = "prettier-plugin-tailwindcss";
    rev = "v${version}";
    sha256 = "sha256-vJuptSGfoKPVf58gHnLNnoRUKOno++OI9lKP2UIX5L8=";
  };

  npmDepsHash = "sha256-NvVc6GFuHii//MoGkPLyrUDvuCMGJaQCWHyQt9fvAXU=";

  dontNpmPrune = true;

  # Fixes error: Cannot find module 'prettier'
  postInstall = ''
    pushd "$nodeModulesPath"
    find -mindepth 1 -maxdepth 1 -type d -print0 | grep --null-data -Exv "\./(ulid|prettier)" | xargs -0 rm -rfv
    popd
  '';

  meta = {
    description = "A Prettier plugin for Tailwind CSS that automatically sorts classes based on our recommended class order. ";
    mainProgram = "prettier-plugin-tailwindcss";
    homepage = "https://github.com/tailwindlabs/prettier-plugin-tailwindcss";
  };
}
