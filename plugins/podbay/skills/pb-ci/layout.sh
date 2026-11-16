#!/usr/bin/env bash
# Checks that the Pod Bay build layout is the one the pb-ci image was made for.
# Usage: layout.sh <checkout>. Prints each mismatch and exits 3 if there is any.
set -u
c="$1"
bad=()
need() { [ -e "$c/$1" ] || bad+=("missing $1"); }
has() { grep -qF -- "$2" "$c/$1" 2>/dev/null || bad+=("$1 no longer has: $2"); }
hasnt() { ! grep -qE -- "$2" "$c/$1" 2>/dev/null || bad+=("$1 now has: $2"); }

for f in Cargo.toml Cargo.lock build.rs src/main.rs src/ui/tests.rs tests/mesh.rs; do need "$f"; done
for f in rust-toolchain rust-toolchain.toml src/lib.rs; do [ -e "$c/$f" ] && bad+=("new file $f"); done
has Cargo.toml 'name = "podbay"'
has Cargo.toml 'edition = "2024"'
hasnt Cargo.toml '^\[workspace\]'
hasnt Cargo.toml '^rust-version'
hasnt Cargo.toml '^\[\[bin\]\]'
has Cargo.toml 'features = ["glow", "default_fonts", "accesskit", "x11", "wayland", "clipboard", "links"]'
has Cargo.toml 'egui_kittest = { version = "0.37.0", features = ["wgpu", "snapshot"] }'
has build.rs 'PODBAY_ENV'

if [ ${#bad[@]} -gt 0 ]; then
  echo "pb-ci: the Pod Bay build layout changed, so the CI image may no longer match:"
  printf '  - %s\n' "${bad[@]}"
  echo "pb-ci: update skills/pb-ci/Dockerfile (Rust version, system libraries) and layout.sh in podbay-kit, then rerun."
  exit 3
fi
grep -q 'fn an_answer_to_an_old_search_' "$c/src/ui/tests.rs" || echo "pb-ci: note: the known flaky test an_answer_to_an_old_search_* is gone; drop its retry from inner.sh."
exit 0
