#!/usr/bin/env bash
# Local CI for Pod Bay in Docker (GitLab has no runner). Linux only: macOS-only code is not covered.
# Usage: pb-ci.sh <podbay checkout> [--skip-mesh]
# Exit: 0 all gates pass, 1 a gate failed, 2 dirty checkout, 3 layout changed, 4 no Docker.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ $# -ge 1 ] || { echo "usage: pb-ci.sh <podbay checkout> [--skip-mesh]"; exit 64; }
checkout="$(git -C "$1" rev-parse --show-toplevel)"
skip_mesh=0; [ "${2:-}" = "--skip-mesh" ] && skip_mesh=1

if [ -n "$(git -C "$checkout" status --porcelain -- . ':(exclude).podbay')" ]; then
  echo "pb-ci: $checkout has uncommitted changes. Commit or stash them, so the result matches a commit."
  exit 2
fi
sha="$(git -C "$checkout" rev-parse --short=12 HEAD)"
full_sha="$(git -C "$checkout" rev-parse HEAD)"
# One shared target volume. Every checkout is mounted at /src and cargo decides rebuilds by
# file mtime, so inner.sh cleans the podbay crate when the checkout or commit changes.
target_vol="pb-ci-target"
bash "$here/layout.sh" "$checkout" || exit 3
docker info >/dev/null 2>&1 || { echo "pb-ci: Docker is not running. Start Docker Desktop (open -a Docker) and rerun."; exit 4; }

image="pb-ci:$(shasum -a 256 "$here/Dockerfile" | cut -c1-12)"
docker image inspect "$image" >/dev/null 2>&1 || docker build -q -t "$image" "$here" >/dev/null

# A git worktree's .git is a file that points into the main repo's git folder. Mount that folder
# read-only at the same path, so git inside the container (inner.sh, build.rs) can read the commit.
git_mount=()
common="$(git -C "$checkout" rev-parse --path-format=absolute --git-common-dir)"
if [ "$common" != "$checkout/.git" ]; then
  [ -d "$common" ] || { echo "pb-ci: cannot find the git folder $common for this worktree."; exit 2; }
  git_mount=(-v "$common":"$common":ro)
fi

mkdir -p "$checkout/.podbay/ci"
log="$checkout/.podbay/ci/$sha.log"
t0=$SECONDS
set +e
docker run --rm \
  -v "$checkout":/src:ro -v "$here":/ci:ro ${git_mount[@]+"${git_mount[@]}"} \
  -v "$target_vol":/target -v pb-ci-cargo-registry:/usr/local/cargo/registry -v pb-ci-cargo-git:/usr/local/cargo/git \
  -e SKIP_MESH="$skip_mesh" -e PBCI_SHA="$full_sha" -e PBCI_CHECKOUT="$checkout" -e PBCI_TARGET="$target_vol" "$image" bash /ci/inner.sh >"$log" 2>&1
rc=$?
set -e

summary="pb-ci $sha"
while read -r _ name result secs rest; do summary+=" $name=$result${rest:+($rest)}"; done < <(grep '^PBCI ' "$log")
summary+=" total=$((SECONDS - t0))s log=.podbay/ci/$sha.log"
echo "$summary" | tee -a "$log"
[ $rc -eq 0 ] || exit 1
