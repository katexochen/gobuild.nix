{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/fsnotify/fsnotify";
  version = "1.8.0";

  src = fetchFromGoProxy {
    importPath = "github.com/fsnotify/fsnotify";
    version = "v${finalAttrs.version}";
    hash = "sha256-xuryvUHfpiQbFPpl2bSJM0Au17RYrZmlAdK6W3KO9Wc=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."golang.org/x/sys"
  ];
})
