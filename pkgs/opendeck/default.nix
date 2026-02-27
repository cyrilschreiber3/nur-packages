# https://www.reddit.com/r/NixOS/comments/1ljik1j/opendeck/
# https://github.com/NixOS/nixpkgs/pull/358223
# https://github.com/NixOS/nixpkgs/issues/356016
# https://github.com/StreamController/StreamController
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  deno,
  nodejs,
  cargo-tauri,
  pkg-config,
  wrapGAppsHook3,
  makeBinaryWrapper,
  makeSetupHook,
  callPackage,
  openssl,
  libxkbcommon,
  webkitgtk_4_1,
  udev,
  libayatana-appindicator,
}: let
  pname = "opendeck";
  version = "2.9.1";

  patchedDeno = deno.overrideAttrs (oldAttrs: {
    passthru =
      (oldAttrs.passthru or {})
      // {
        fetchDeps = callPackage ./deno-utils/fetch-deps.nix {};
        setupHook =
          makeSetupHook {
            name = "deno-setup-hook";
            propagatedBuildInputs = [deno];
          }
          ./deno-utils/setup-hook.sh;
        compileHook =
          makeSetupHook {
            name = "deno-compile-hook";
            propagatedBuildInputs = [deno];
            substitutions.deno = deno;
          }
          ./deno-utils/compile-hook.sh;
      };
  });

  src = fetchFromGitHub {
    owner = "ninjadev64";
    repo = "OpenDeck";
    rev = "refs/tags/v${version}";
    hash = "sha256-vAUhZNvEH+X/ez0Gc+xIKRXR16ykx9Vl5160+h1Y2OI=";
  };

  # Vendor the starterpack plugin's Cargo dependencies (built separately via build.rs/build.ts)
  pluginCargoDeps = rustPlatform.importCargoLock {
    lockFile = ./plugin-Cargo.lock;
    outputHashes = {
      "enigo-0.6.1" = "sha256-zcxgs30L5dQiq/tJNUla6rwZvS2FGOc0O7tTDKifLPo=";
    };
  };
in
  rustPlatform.buildRustPackage {
    inherit pname version src;

    postPatch = ''
      # syntax: bash
      # Very strangely, OpenDeck does not use a Cargo workspace for Tauri and instead has its Rust
      # component entirely with src-tauri — buildRustPackage really dislikes this so we symlink the
      # Cargo.lock to the root directory. Setting sourceRoot also breaks tauri build as it assumes
      # the build directory to be at the project root, where the node_modules are.
      #
      # It's a mess.
      ln -s src-tauri/Cargo.lock Cargo.lock

      # Set up vendored cargo deps for the starterpack plugin so it can build offline
      mkdir -p plugins/com.amansprojects.starterpack.sdPlugin/.cargo
      cat > plugins/com.amansprojects.starterpack.sdPlugin/.cargo/config.toml << CARGOCONFIG
      [source.crates-io]
      replace-with = "vendored-sources"

      [source."git+https://github.com/enigo-rs/enigo.git?rev=4cb8833144e6e5e679b91ae7fd53507f9abf751d"]
      git = "https://github.com/enigo-rs/enigo.git"
      rev = "4cb8833144e6e5e679b91ae7fd53507f9abf751d"
      replace-with = "vendored-sources"

      [source.vendored-sources]
      directory = "${pluginCargoDeps}"
      CARGOCONFIG
      # syntax: bash

      # The plugin build script (build.ts) imports @std/fs and @std/path from JSR, which requires
      # network access. Replace it with an equivalent using only Deno built-in APIs.
      cat > plugins/com.amansprojects.starterpack.sdPlugin/build.ts << 'BUILDSCRIPT'
      // syntax: ts
      /// <reference lib="deno.ns" />

      if (Deno.args.length < 2) Deno.exit(1);
      const outDir = Deno.args[0];
      const target = Deno.args[1];

      try {
        await Deno.remove(outDir, { recursive: true });
      } catch (error: any) {
        if (!(error instanceof Deno.errors.NotFound)) throw error;
      }

      async function copyDir(src: string, dest: string): Promise<void> {
        await Deno.mkdir(dest, { recursive: true });
        for await (const entry of Deno.readDir(src)) {
          const s = src + "/" + entry.name;
          const d = dest + "/" + entry.name;
          if (entry.isDirectory) await copyDir(s, d);
          else await Deno.copyFile(s, d);
        }
      }

      await copyDir("assets", outDir);
      const tmpHome = Deno.makeTempDirSync();
      const tmpTarget = Deno.makeTempDirSync();
      if (
        !(
          await new Deno.Command("cargo", {
            args: ["install", "--frozen", "--path", ".", "--target", target, "--root", outDir + "/" + target],
            env: { ...Deno.env.toObject(), CARGO_HOME: tmpHome, CARGO_TARGET_DIR: tmpTarget },
          }).spawn().status
        ).success
      ) Deno.exit(1);
      BUILDSCRIPT

      # syntax: bash

      # Disable lock file usage in plugin builds — no remote deps to lock anymore
      substituteInPlace src-tauri/build.rs \
        --replace-fail '"--lock=target/deno.lock",' '"--no-lock",'
    '';

    denoDepsHash = "sha256-gFvUH2I0+EkA1LrrgLfGX+LgITSz1K7ehVzv67saEqc=";

    denoDeps = patchedDeno.fetchDeps {
      inherit pname src;
      hash = denoDepsHash;
      denoInstallFlags = ["--allow-scripts"];
    };

    cargoHash = "sha256-KVHqDFArluY98lH+hnSWwJrIVD7FXrvOsL6moQd9bpE=";
    cargoRoot = "src-tauri";
    buildAndTestSubdir = "src-tauri";

    nativeBuildInputs = [
      patchedDeno.setupHook
      nodejs
      cargo-tauri.hook
      pkg-config
      wrapGAppsHook3
      makeBinaryWrapper
    ];

    buildInputs =
      [openssl]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        webkitgtk_4_1
        libxkbcommon
        udev
        libayatana-appindicator
      ];

    postInstall = ''
      # syntax: bash
      # Somehow the udev rules aren't autoinstalled
      install -Dm644 src-tauri/bundle/40-streamdeck.rules -t $out/lib/udev/rules.d
    '';

    postFixup = ''
      # syntax: bash
      wrapProgram $out/bin/opendeck \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libayatana-appindicator]}
    '';

    meta = {
      broken = lib.versionOlder lib.version "26.04";
      preferLocalBuild = true; # The hash of the bundled Deno deps changed based on your nixpkgs version, so it's easier to just build locally
      description = "Cross-platform desktop application that provides functionality for stream controller devices";
      homepage = "https://github.com/ninjadev64/OpenDeck";
      changelog = "https://github.com/ninjadev64/OpenDeck/releases/tag/v${version}";
      license = with lib.licenses; [gpl3Plus];
      maintainers = with lib.maintainers; [pluiedev];
      platforms = with lib.platforms; linux;
      mainProgram = "opendeck";
    };
  }
