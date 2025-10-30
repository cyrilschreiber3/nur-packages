{
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "prettier-plugin-tailwindcss-extra-plus";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "joefitzgerald";
    repo = "prettier-plugin-tailwindcss-extra-plus";
    rev = "v${version}";
    sha256 = "sha256-iziOV950ltw5hT9Gx5sFzJVrG8D73bejrHtCzrmbqcc=";
  };

  npmDepsHash = "sha256-xei/0BwwqdKsMp7E3iMU5kAybZHd1a7ZgjbKYb2eWYo=";

  dontNpmPrune = true;

  postPatch = ''
    ln -s ${./prettier-plugin-tailwindcss-extra-plus-fix-deps.json} ./package-lock.json
  '';

  # Fixes error: Cannot find module 'prettier'
  postInstall = ''
    pushd "$nodeModulesPath"
    find -mindepth 1 -maxdepth 1 -type d -print0 | grep --null-data -Exv "\./(ulid|prettier)" | xargs -0 rm -rfv
    popd
  '';

  meta = {
    description = "Adds Tailwind class sorting to a set of languages that are not yet supported by prettier.";
    mainProgram = pname;
    homepage = "https://github.com/joefitzgerald/prettier-plugin-tailwindcss-extra-plus";
  };
}
