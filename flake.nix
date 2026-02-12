{
  description = "shdoc - documentation generator for shell scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23d72dabcb3b12469f57b37170fcbc1789bd7457";
    nixpkgs-master.url = "github:NixOS/nixpkgs/b28c4999ed71543e71552ccfd0d7e68c581ba7e9";
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
