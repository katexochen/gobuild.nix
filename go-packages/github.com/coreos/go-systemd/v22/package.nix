{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/coreos/go-systemd/v22";
  version = "22.5.0";

  src = fetchFromGoProxy {
    importPath = "github.com/coreos/go-systemd/v22";
    version = "v${finalAttrs.version}";
    hash = "sha256-U1msfUWP5JSS2W3vfpbEs+OkwAxi+MJgIawp/qwke6k=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/godbus/dbus/v5"
  ];
})
