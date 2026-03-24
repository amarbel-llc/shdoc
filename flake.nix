{
  description = "shdoc - documentation generator for shell scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/4590696c8693fea477850fe379a01544293ca4e2";
    nixpkgs-master.url = "github:NixOS/nixpkgs/e2dde111aea2c0699531dc616112a96cd55ab8b5";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-master,
      utils,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "shdoc";
          version = "1.2";

          src = pkgs.fetchFromGitHub {
            owner = "reconquest";
            repo = "shdoc";
            rev = "v1.2";
            sha256 = "sha256-oBOXeISPv43VgE6bzPzr6BvVfFwDo1Wx7ekp07w9h6s=";
          };

          dontBuild = true;

          buildInputs = [ pkgs.gawk ];
          nativeBuildInputs = [ pkgs.makeWrapper ];

          installPhase = ''
            mkdir -p $out/bin

            cp shdoc $out/bin/
            cp ${./shdoc-fish_completion} $out/bin/shdoc-fish_completion

            wrapProgram $out/bin/shdoc --prefix PATH : ${pkgs.gawk}/bin

            # wrapProgram $out/bin/shdoc-fish_completion --prefix PATH : ${pkgs.gawk}/bin
          '';
        };
      }
    );
}
