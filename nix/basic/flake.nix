{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {self, nixpkgs, flake-utils}:
    let
      overlay-nix = final: prev:
        let prefix = "/home/testuser/nix";
        in
        {
          nix_prefix = (prev.nix.override {
            storeDir = "${prefix}/store";
            stateDir = "${prefix}/var";
            confDir = "${prefix}/etc";
          }).overrideAttrs (oldAttrs: rec {
            patches = (oldAttrs.patches or []) ++ [./nix_patch_2_5.patch];
          });
        };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs {overlays = [overlay-nix]; inherit system;}; in
        {
          packages.nix = pkgs.nix_prefix;
        }
      );
}
