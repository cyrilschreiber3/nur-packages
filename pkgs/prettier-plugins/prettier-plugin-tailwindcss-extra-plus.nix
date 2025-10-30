{
  fetchFromGitHub,
  nodejs,
  pnpm,
  stdenv,
}: let
  version = "0.3.1";
  name = "prettier-plugin-tailwindcss-extra-plus";
in
  stdenv.mkDerivation (finalAttrs: {
    pname = name;
    version = version;

    src = fetchFromGitHub {
      owner = "joefitzgerald";
      repo = "prettier-plugin-tailwindcss-extra-plus";
      rev = "v${version}";
      sha256 = "sha256-iziOV950ltw5hT9Gx5sFzJVrG8D73bejrHtCzrmbqcc=";
    };

    nativeBuildInputs = [
      nodejs
      pnpm.configHook
    ];

    pnpmDeps = pnpm.fetchDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 2;
      hash = "sha256-nKqDX7ahhrfer2cZ6Mt2CuL/481EBzdKY9OFGczAmm4=";
    };

    buildPhase = ''
      pnpm run build
    '';

    installPhase = ''
      mkdir -p $out/lib/node_modules/${name}/dist
      cp -r dist $out/lib/node_modules/${name}
      cp -r node_modules $out/lib/node_modules/${name}
      chmod -R +x $out/lib
    '';

    meta = {
      description = "Adds Tailwind class sorting to a set of languages that are not yet supported by prettier.";
      mainProgram = name;
      homepage = "https://github.com/joefitzgerald/prettier-plugin-tailwindcss-extra-plus";
    };
  })
