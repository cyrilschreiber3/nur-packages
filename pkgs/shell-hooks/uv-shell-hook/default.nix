{
  makeSetupHook,
  uv,
}:
makeSetupHook {
  name = "uv-shell-hook";

  propagatedBuildInputs = [uv];

  substitutions = {
    uvBin = "${uv}/bin/uv";
  };

  passthru.provides.setupHook = true;
}
./uv-shell-hook.sh
