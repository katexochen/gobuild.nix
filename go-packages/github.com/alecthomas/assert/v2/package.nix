{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/alecthomas/assert/v2";
  version = "2.11.0";

  src = fetchFromGoProxy {
    importPath = "github.com/alecthomas/assert/v2";
    version = "v${finalAttrs.version}";
    hash = "sha256-u4hJQUW2Wh4eh9uEpjwEJNEvzo3WB9oJSBgc50BNPqw=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/alecthomas/repr"
    goPackages."github.com/hexops/gotextdiff"
  ];
})
