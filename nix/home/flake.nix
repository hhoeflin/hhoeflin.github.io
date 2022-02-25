{
  description = "Home Manager NixOS configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    {
      homeConfigurations = {
        testuser = inputs.home-manager.lib.homeManagerConfiguration {
          system = "x86_64-linux";
          # Home Manager needs a bit of information about you and the
          # paths it should manage.
          homeDirectory = "/home/testuser";
          username = "testuser";
          # This value determines the Home Manager release that your
          # configuration is compatible with. This helps avoid breakage
          # when a new Home Manager release introduces backwards
          # incompatible changes.
          # You can update Home Manager without changing this value. See
          # the Home Manager release notes for a list of state version
          # changes in each release.
          stateVersion = "21.11";

          configuration = { config, pkgs, ... }:
            let
              overlay-nix = final: prev:
                let prefix = "/home/testuser/nix";
                in
	        {
                  nix_2_3 = (prev.nix_2_3.override {
                    storeDir = "${prefix}/store";
                    stateDir = "${prefix}/var";
                    confDir = "${prefix}/etc";
                  }).overrideAttrs (oldAttrs: rec {
    	            patches = (oldAttrs.patches or []) ++ [./nix_patch_2_3.patch];
                  });
                  nix = (prev.nix.override {
                    storeDir = "${prefix}/store";
                    stateDir = "${prefix}/var";
                    confDir = "${prefix}/etc";
                  }).overrideAttrs (oldAttrs: rec {
    	            patches = (oldAttrs.patches or []) ++ [./nix_patch_2_5.patch];
                  });
              };
            in
            {
              nixpkgs.overlays = [ overlay-nix];
              nixpkgs.config = {
                allowUnfree = true;
                allowBroken = true;
              };

              imports = [
                ./home.nix
              ];

            };
        };
      };
      testuser = self.homeConfigurations.testuser.activationPackage;
      defaultPackage.x86_64-linux = self.testuser;
    };
}
