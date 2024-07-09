{
  stdenv,
  fetchurl,
  unzip,
  gitUpdater,
}:
stdenv.mkDerivation rec {
  pname = "nx_tzdb";
  version = "221202";

  src = fetchurl {
    url = "https://git.the127001.ch/yuzu-mirror/tzdb_to_nx/releases/download/${version}/${version}.zip";
    hash = "sha256-mRzW+iIwrU1zsxHmf+0RArU8BShAoEMvCz+McXFFK3c=";
  };

  nativeBuildInputs = [unzip];

  buildCommand = ''
    unzip $src -d $out
  '';

  passthru.updateScript = gitUpdater {
    url = "https://git.the127001.ch/yuzu-mirror/tzdb_to_nx.git";
  };
}
