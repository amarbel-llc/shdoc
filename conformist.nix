# This repo's conformist overlay, merged with conformist.lib.presets.eng in
# flake.nix. See conformist(7), conformist-nix(7), eng-versioning(7).
{ ... }:
{
  # nixfmt formats flake.nix and this file.
  programs.nixfmt.enable = true;

  # Shell glue (tests/*.sh, examples/*.sh). 2-space indent, matching eng's
  # shfmt convention (`-s -i=2 -ci`; case-indent isn't exposed by the
  # conformist shfmt module).
  programs.shfmt = {
    enable = true;
    indent_size = 2;
  };

  # eng-versioning(7) derives the version key from go.mod / go.nix / Cargo.toml.
  # This repo has none of those, so pin it explicitly to match version.env.
  linters.eng-versioning.key = "SHDOC_VERSION";

  settings.excludes = [
    # Vendored upstream bash libraries (the import.bash submodule, plus the
    # runtime-cloned deps import.bash's own import:use fetches into vendor/
    # at test time — see vendor/.gitignore) — not ours to reformat.
    "vendor/**"
    # Generated example output, not source.
    "examples/*.md"
    # Prose and generated files are out of scope for code formatters.
    "*.md"
    "flake.lock"
    "LICENSE"
  ];
}
