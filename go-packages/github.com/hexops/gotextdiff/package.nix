{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/hexops/gotextdiff";
  version = "1.0.3";

  src = fetchFromGoProxy {
    importPath = "github.com/hexops/gotextdiff";
    version = "v${finalAttrs.version}";
    hash = "sha256-PQ5UI9aRbt7n90ptsS3fs00AfGDiS5Kaxm5OJrjwwo0=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
