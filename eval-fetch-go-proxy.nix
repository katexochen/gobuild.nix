{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs { },

  fetchFromGoProxyPath ? ./fetch-from-go-proxy.nix,
  importPath,
  version,
  hash ? "",
}:

let
  fetchFromGoProxy = pkgs.callPackage fetchFromGoProxyPath { };
in

fetchFromGoProxy {
  inherit importPath version hash;
}
