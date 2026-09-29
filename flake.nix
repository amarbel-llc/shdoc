{
  description = "shdoc - documentation generator for shell scripts";

  inputs = {
    igloo.url = "https://code.linenisgreat.com/igloo/archive/master.tar.gz";
    igloo.inputs.nixpkgs-master.follows = "nixpkgs-master";
    nixpkgs-master.url = "github:NixOS/nixpkgs/7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
    utils.inputs.systems.follows = "igloo/systems";

    # conformist provides the linter/formatter multiplexer, its Nix module
    # library (conformist.lib), and the eng-convention presets. Config lives
    # in ./conformist.nix (+ conformist.lib.presets.{eng,eng-impure} below).
    conformist = {
      url = "https://code.linenisgreat.com/conformist/archive/master.tar.gz";
      inputs.igloo.follows = "igloo";
      inputs.nixpkgs-master.follows = "nixpkgs-master";
      inputs.utils.follows = "utils";
    };
  };

  outputs =
    {
      self,
      igloo,
      utils,
      conformist,
      ...
    }@inputs:
    let
      # eng-versioning(7): version.env at repo root is the single source of
      # truth. The match captures everything after SHDOC_VERSION= up to the
      # line break; the `export` prefix is tolerated.
      shdocVersion = builtins.head (
        builtins.match ".*SHDOC_VERSION=([^\n]+).*" (builtins.readFile ./version.env)
      );
    in
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import igloo { inherit system; };

        conformistPkg = conformist.packages.${system}.default;

        # Pure lane: the eng preset (sandboxed eng-convention linters) + this
        # repo's formatters/excludes (./conformist.nix). Drives `nix fmt`
        # (build.wrapper), the sandboxed checks.formatting (build.check), and
        # the conformist-pre-commit hook (build.preCommit).
        conformistEval = conformist.lib.evalModule pkgs {
          imports = [
            conformist.lib.presets.eng
            ./conformist.nix
          ];
          package = conformistPkg;
        };

        # Impure lane: the git-state eng-convention checks (git-remotes,
        # git-default-branch, sweatfile, agents-md) — they need a live .git,
        # so they run against the working tree via `just lint-worktree`.
        conformistImpureEval = conformist.lib.evalModule pkgs {
          imports = [ conformist.lib.presets.eng-impure ];
          package = conformistPkg;
          projectRootFile = "flake.nix";
        };

        # The checked-out `shdoc` gawk script + fish completion, wrapped with
        # gawk on PATH. Sourced from the working tree (not a fetchFromGitHub
        # of some upstream tag) so this always packages what's actually
        # checked out here, patches included — filtered to just the two files
        # the derivation needs, so editing tests/, docs, or vendor/ doesn't
        # bust this derivation's hash.
        shdoc = pkgs.stdenv.mkDerivation {
          pname = "shdoc";
          version = shdocVersion;

          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./shdoc
              ./shdoc-fish_completion
            ];
          };

          buildInputs = [ pkgs.gawk ];
          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin
            cp shdoc $out/bin/
            cp shdoc-fish_completion $out/bin/shdoc-fish_completion
            wrapProgram $out/bin/shdoc --prefix PATH : ${pkgs.gawk}/bin
          '';
        };
      in
      {
        packages = {
          inherit shdoc;
          default = shdoc;
          # The generated impure-lane config, consumed by `just lint-worktree`.
          conformist-impure-config = conformistImpureEval.config.build.configFile;
          # The store-pinned `conformist --staged --exit-zero-on-fix` hook;
          # the sweatfile names it as the per-commit hook.
          conformist-pre-commit = conformistEval.config.build.preCommit;
          # Its merge-repair sibling: `nix build .#conformist-repair`.
          conformist-repair = conformistEval.config.build.repair;
          # The raw conformist binary, so `just lint-worktree` can
          # `nix run .#conformist -- check ...` instead of resolving
          # `conformist` from PATH — where eng's cwd-aware wrapper
          # (conformistCwd) would shadow it and refuse (see justfile).
          conformist = conformistPkg;
        };

        formatter = conformistEval.config.build.wrapper;
        checks.formatting = conformistEval.config.build.check self;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.gawk
            pkgs.just
            conformistPkg
            conformistEval.config.build.preCommit
            conformistEval.config.build.repair
          ];
        };
      }
    );
}
