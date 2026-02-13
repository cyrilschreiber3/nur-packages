{
  makeSetupHook,
  uv,
  writeShellScriptBin,
}:
makeSetupHook {
  name = "uv-shell-hook";

  propagatedBuildInputs = [
    uv
    (writeShellScriptBin "uv-env-info" (builtins.readFile ./uv-env-info.sh))
  ];

  substitutions = {
    uvBin = "${uv}/bin/uv";
  };

  passthru.provides.setupHook = true;
}
./uv-shell-hook.sh
