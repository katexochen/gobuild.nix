{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  systemdLibs,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/coreos/go-systemd/v22";
  version = "22.5.0";

  src = fetchFromGoProxy {
    importPath = "github.com/coreos/go-systemd/v22";
    version = "v${finalAttrs.version}";
    hash = "sha256-zjFAWCG5CiDitC/qkY0/7C95887WGMlYFA9bxZVZRk8=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/godbus/dbus/v5"
    systemdLibs
  ];
})
