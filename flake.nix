{
  description = "COE 379L (Fall 2025) Documentation";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    shell-utils.url = "github:waltermoreira/shell-utils";
  };

  outputs = { nixpkgs, flake-utils, shell-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (shell-utils.lib.${system}) shell;
        python = pkgs.python313;
        docsPython = python.withPackages (ps: [
          ps.sphinx
          ps.sphinx-autobuild
          ps.sphinx_rtd_theme
          ps.sphinx-tabs
          ps.docutils
          ps.setuptools
        ]);
        commonPackages = [
          docsPython
          pkgs.rsync
          pkgs.gnumake
          pkgs.lesspipe
          pkgs.less
          pkgs.coreutils
          pkgs.bashInteractive
          pkgs.which
        ];
        html = pkgs.stdenv.mkDerivation {
          # builds to ./result
          name = "coe379l";
          src = ./.;
          buildInputs = commonPackages;
          buildPhase = ''
            make html
          '';
          installPhase = ''
            mkdir -p $out
            rsync -av _build/html $out/
          '';
        };

      in
      {
        devShells.default = shell {
          name = "379L";
          buildInputs = commonPackages;
        };
        packages.default = html;
      }
    );
}
