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
bash "$here/layout.sh" "$checkout" || exit 3
docker info >/dev/null 2>&1 || { echo "pb-ci: Docker is not running. Start Docker Desktop (open -a Docker) and rerun."; exit 4; }

image="pb-ci:$(shasum -a 256 "$here/Dockerfile" | cut -c1-12)"
docker image inspect "$image" >/dev/null 2>&1 || docker build -q -t "$image" "$here" >/dev/null

mkdir -p "$checkout/.podbay/ci"
log="$checkout/.podbay/ci/$sha.log"
t0=$SECONDS
set +e
docker run --rm \
  -v "$checkout":/src:ro -v "$here":/ci:ro \
  -v pb-ci-target:/target -v pb-ci-cargo-registry:/usr/local/cargo/registry -v pb-ci-cargo-git:/usr/local/cargo/git \
  -e SKIP_MESH="$skip_mesh" "$image" bash /ci/inner.sh >"$log" 2>&1
rc=$?
set -e

summary="pb-ci $sha"
while read -r _ name result secs rest; do summary+=" $name=$result${rest:+($rest)}"; done < <(grep '^PBCI ' "$log")
summary+=" total=$((SECONDS - t0))s log=.podbay/ci/$sha.log"
echo "$summary" | tee -a "$log"
[ $rc -eq 0 ] || exit 1
