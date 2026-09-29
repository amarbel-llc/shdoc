# this repo's justfile. Conventions: conformist-justfile(7). `default` is the
# read-only CI lane; `just` passing means the tree is conformant.

default: lint build test

# --- lint ---

lint: lint-fmt lint-worktree

# Read-only formatting + the eng preset's file-based linters, via the sandboxed
# checks.formatting derivation. Does NOT modify files --- the modifying
# counterpart is `codemod-fmt`.
#
# run the read-only formatting check
[group('lint')]
lint-fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
    nix build ".#checks.${system}.formatting" --no-link --print-build-logs

# Impure eng checks (git remotes, sweatfile, agents-md) against the working
# tree. The binary comes from `.#conformist`, NOT from PATH: eng's
# home-profile wrapper (conformistCwd) also installs a `conformist`, and it
# gates on a checked-in conformist.toml/.conformist.toml/treelint.toml at the
# git root, exiting 2 before it ever reads --config-file. No eng repo carries
# one — the config is Nix-generated (.#conformist-impure-config) — so whenever
# the profile bin wins the PATH race (any run outside the devShell) a bare
# `conformist` fails this lane. `nix run` makes it PATH-order independent.
#
# run the impure eng checks against the working tree
[group('lint')]
lint-worktree:
    #!/usr/bin/env bash
    set -euo pipefail
    cfg=$(nix build --no-link --print-out-paths '.#conformist-impure-config')
    nix run '.#conformist' -- check --config-file "$cfg" --tree-root .

# --- build ---

build: build-nix

# Build the packaged shdoc (the checked-out shdoc/shdoc-fish_completion,
# wrapped with gawk on PATH) via nix, matching packages.default.
#
# build the shdoc package via nix
[group('build')]
build-nix:
    nix build --show-trace

# --- test ---

test: test-shdoc

# Runs the vendored bash test suite (tests/run_tests, from upstream
# reconquest/shdoc). Pre-seeds test-runner.bash + its transitive deps
# (opts.bash, types.bash, tests.sh, coproc.bash) into vendor/github.com/reconquest/
# — the exact set vendor/.gitignore already expects, since they're normally
# fetched on demand by the vendored import.bash's import:use — before
# delegating. Pre-seeding is deliberate, not cosmetic: import:use resolves its
# clone destination by walking UP through parent git repositories, and when
# this checkout is nested under a larger monorepo (e.g. eng's repos/ tree) that
# walk escapes this repo and clones into the enclosing repo's root instead.
# Once each dep already exists at its expected vendor path, import:use's local
# fast-path is used and that walk never runs. Only fetches what's missing —
# a repeat run in the same checkout is fully offline.
#
# run the vendored bash test suite
[group('test')]
test-shdoc:
    #!/usr/bin/env bash
    set -euo pipefail
    git submodule update --init --recursive
    for dep in tests.sh opts.bash types.bash test-runner.bash coproc.bash; do
      dir="vendor/github.com/reconquest/$dep"
      if [ ! -e "$dir/$dep" ]; then
        git clone --quiet "https://github.com/reconquest/$dep" "$dir"
      fi
    done
    bash tests/run_tests

# --- codemod ---

codemod-fmt: codemod-fmt-tree

# format the tree in place (repair mode) via `nix fmt`
[group('codemod')]
codemod-fmt-tree:
    nix fmt
