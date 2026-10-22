{
  description = "Leon's website";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      perSystem = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          treefmt = treefmt-nix.lib.evalModule pkgs {
            projectRootFile = "flake.nix";

            programs.nixfmt.enable = true;
            programs.shfmt.enable = true;
            programs.black.enable = true;
          };
          formatter = treefmt.config.build.wrapper;

          gitRev = self.rev or self.dirtyRev or "unknown";
          site = import ./site.nix { inherit pkgs gitRev; };

          preview = import ./site.nix {
            inherit pkgs;

            gitRev = "preview";
            baseUrl = "http://localhost:8080";
            doCheck = false;
            renderBlogDrafts = true;
          };

          previewApp = pkgs.writeShellApplication {
            name = "homepage-preview";

            runtimeInputs = [
              pkgs.git
              pkgs.nix
              (pkgs.python3.withPackages (p: [ p.pyinotify ]))
            ];

            text = ''
              cd "$(git rev-parse --show-toplevel)"
              exec python3 -u ${./run.py}
            '';
          };

          deploy = pkgs.writeShellApplication {
            name = "deploy";

            runtimeInputs = with pkgs; [
              openssh
              git
              rsync
              nix
              cacert
              coreutils
              formatter
            ];

            text = builtins.readFile ./deploy.sh;
          };
        in
        {
          packages = {
            default = site;
            inherit site preview deploy;
          };

          apps.deploy = {
            type = "app";
            program = "${deploy}/bin/deploy";
            meta.description = "Validate, build, and publish the website";
          };

          apps.preview = {
            type = "app";
            program = "${previewApp}/bin/homepage-preview";
            meta.description = "Build and serve a live preview at localhost:8080";
          };

          checks = {
            inherit site deploy;

            preview = previewApp;
            formatting = treefmt.config.build.check self;
          };

          inherit formatter;

          devShells.default = import ./shell.nix { inherit pkgs formatter; };
        }
      );
    in
    {
      packages = forAllSystems (system: perSystem.${system}.packages);
      apps = forAllSystems (system: perSystem.${system}.apps);
      checks = forAllSystems (system: perSystem.${system}.checks);
      formatter = forAllSystems (system: perSystem.${system}.formatter);
      devShells = forAllSystems (system: perSystem.${system}.devShells);
    };
}
