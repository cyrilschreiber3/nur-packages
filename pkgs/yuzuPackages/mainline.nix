{
  lib,
  stdenv,
  fetchFromGitea,
  nix-update-script,
  wrapQtAppsHook,
  autoconf,
  boost,
  catch2_3,
  cmake,
  compat-list,
  cpp-jwt,
  cubeb,
  discord-rpc,
  enet,
  fmt,
  glslang,
  libopus,
  libusb1,
  libva,
  lz4,
  nlohmann_json,
  nv-codec-headers-12,
  nx_tzdb,
  pkg-config,
  qtbase,
  qtmultimedia,
  qttools,
  qtwayland,
  qtwebengine,
  SDL2,
  vulkan-headers,
  vulkan-loader,
  yasm,
  zlib,
  zstd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "yuzu";
  version = "1736";

  # src = builtins.fetchGit {
  #   url = "git@git.the127001.ch:yuzu-mirror/yuzu-mainline.git";
  #   ref = "refs/heads/mainline-0-${finalAttrs.version}";
  #   # rev = "27b6fe407f1940ae28531d498dc5dc0076f2c33a";
  #   submodules = true;
  # };
  src = fetchFromGitea {
    domain = "git.the127001.ch";
    owner = "yuzu-mirror";
    repo = "yuzu-mainline";
    rev = "mainline-0-${finalAttrs.version}";
    hash = "sha256-63rqLRM2VXCon9NAAAEampSpaj8Wdkr1mrR/16+C/GQ=";
    fetchSubmodules = true;
  };

  patches = [
    ./vulkan-enum-update.patch
  ];

  nativeBuildInputs = [
    cmake
    glslang
    pkg-config
    qttools
    wrapQtAppsHook
  ];

  buildInputs = [
    # vulkan-headers must come first, so the older propagated versions
    # don't get picked up by accident
    vulkan-headers

    boost
    catch2_3
    cpp-jwt
    cubeb
    discord-rpc
    # intentionally omitted: dynarmic - prefer vendored version for compatibility
    enet

    # vendored ffmpeg deps
    autoconf
    yasm
    libva # for accelerated video decode on non-nvidia
    nv-codec-headers-12 # for accelerated video decode on nvidia
    # end vendored ffmpeg deps

    fmt
    # intentionally omitted: gamemode - loaded dynamically at runtime
    # intentionally omitted: httplib - upstream requires an older version than what we have
    libopus
    libusb1
    # intentionally omitted: LLVM - heavy, only used for stack traces in the debugger
    lz4
    nlohmann_json
    qtbase
    qtmultimedia
    qtwayland
    qtwebengine
    # intentionally omitted: renderdoc - heavy, developer only
    SDL2
    # not packaged in nixpkgs: simpleini
    # intentionally omitted: stb - header only libraries, vendor uses git snapshot
    # not packaged in nixpkgs: vulkan-memory-allocator
    # intentionally omitted: xbyak - prefer vendored version for compatibility
    zlib
    zstd
  ];

  # This changes `ir/opt` to `ir/var/empty` in `externals/dynarmic/src/dynarmic/CMakeLists.txt`
  # making the build fail, as that path does not exist
  dontFixCmake = true;

  cmakeFlags = [
    # actually has a noticeable performance impact
    "-DYUZU_ENABLE_LTO=ON"

    # build with qt6
    "-DENABLE_QT6=ON"
    "-DENABLE_QT_TRANSLATION=ON"

    # use system libraries
    # NB: "external" here means "from the externals/ directory in the source",
    # so "off" means "use system"
    "-DYUZU_USE_EXTERNAL_SDL2=OFF"
    "-DYUZU_USE_EXTERNAL_VULKAN_HEADERS=OFF"

    # don't use system ffmpeg, yuzu uses internal APIs
    "-DYUZU_USE_BUNDLED_FFMPEG=ON"

    # don't check for missing submodules
    "-DYUZU_CHECK_SUBMODULES=OFF"

    # enable some optional features
    "-DYUZU_USE_QT_WEB_ENGINE=ON"
    "-DYUZU_USE_QT_MULTIMEDIA=ON"
    "-DUSE_DISCORD_PRESENCE=ON"

    # We dont want to bother upstream with potentially outdated compat reports
    "-DYUZU_ENABLE_COMPATIBILITY_REPORTING=OFF"
    "-DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF" # We provide this deterministically
  ];

  # Does some handrolled SIMD
  env.NIX_CFLAGS_COMPILE = "-msse4.1";

  # Fixes vulkan detection.
  # FIXME: patchelf --add-rpath corrupts the binary for some reason, investigate
  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${vulkan-loader}/lib"
  ];

  postPatch = ''
    echo "Verifying patch application:"
    grep -n "VK_DRIVER_ID_MESA_HONEYKRISP" externals/Vulkan-Utility-Libraries/include/vulkan/vk_enum_string_helper.h || echo "Patch not applied correctly"

    echo "Contents of vk_enum_string_helper.h after patching:"
    sed -n '3476,3486p' externals/Vulkan-Utility-Libraries/include/vulkan/vk_enum_string_helper.h
  '';

  preConfigure = ''
    # see https://github.com/NixOS/nixpkgs/issues/114044, setting this through cmakeFlags does not work.
    cmakeFlagsArray+=(
      "-DTITLE_BAR_FORMAT_IDLE=${finalAttrs.pname} | ${finalAttrs.version} (nixpkgs) {}"
      "-DTITLE_BAR_FORMAT_RUNNING=${finalAttrs.pname} | ${finalAttrs.version} (nixpkgs) | {}"
    )

    # provide pre-downloaded tz data
    mkdir -p build/externals/nx_tzdb
    ln -s ${nx_tzdb} build/externals/nx_tzdb/nx_tzdb
  '';

  # This must be done after cmake finishes as it overwrites the file
  postConfigure = ''
    ln -sf ${compat-list} ./dist/compatibility_list/compatibility_list.json
  '';

  postInstall = ''
    install -Dm444 $src/dist/72-yuzu-input.rules $out/lib/udev/rules.d/72-yuzu-input.rules
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--version-regex" "mainline-0-(.*)"];
  };

  meta = with lib; {
    homepage = "https://yuzu-emu.org";
    changelog = "https://yuzu-emu.org/entry";
    description = "An experimental Nintendo Switch emulator written in C++";
    longDescription = ''
      An experimental Nintendo Switch emulator written in C++.
      Using the mainline branch is recommended for general usage.
      Using the early-access branch is recommended if you would like to try out experimental features, with a cost of stability.
    '';
    mainProgram = "yuzu";
    platforms = ["x86_64-linux"];
    license = with licenses; [
      gpl3Plus
      # Icons
      asl20
      mit
      cc0
    ];
  };
})
