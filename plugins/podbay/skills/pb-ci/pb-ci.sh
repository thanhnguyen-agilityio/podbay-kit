#!/usr/bin/env bash
# Local CI for Pod Bay in Docker (GitLab has no runner). Linux only: macOS-only code is not covered.
# Usage: pb-ci.sh <podbay checkout> [--skip-mesh]
# Exit: 0 all gates pass, 1 a gate failed, 2 dirty checkout, 3 layout changed, 4 no Docker or the image build failed or timed out.
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
if ! docker image inspect "$image" >/dev/null 2>&1; then
  # Build with a docker-driver builder: a selected docker-container builder can be inactive (build
  # hangs) and does not load the image into the local store. Prefer desktop-linux, else default.
  builder=default
  docker buildx inspect desktop-linux >/dev/null 2>&1 && builder=desktop-linux
  limit="${PBCI_BUILD_TIMEOUT:-1200}"
  # The base image is public, so build without the credential helper: docker-credential-desktop
  # hangs when the macOS keychain is locked (ssh or tmux sessions), and the build waits forever.
  cfg="$(mktemp -d)"; trap 'rm -rf "$cfg"' EXIT
  for d in contexts cli-plugins buildx; do [ -e "$HOME/.docker/$d" ] && ln -s "$HOME/.docker/$d" "$cfg/$d"; done
  printf '{"currentContext":"%s"}\n' "$(docker context show 2>/dev/null || echo default)" > "$cfg/config.json"
  echo "pb-ci: building image $image with builder $builder (first run or Dockerfile changed; up to ${limit}s)"
  DOCKER_CONFIG="$cfg" BUILDX_BUILDER="$builder" docker build -q -t "$image" "$here" >/dev/null &
  bpid=$!; waited=0
  while kill -0 "$bpid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      kill "$bpid" 2>/dev/null
      echo "pb-ci: the image build did not finish in ${limit}s (builder $builder). Check Docker Desktop, 'docker buildx ls' and the network to Docker Hub, then rerun. PBCI_BUILD_TIMEOUT=<seconds> changes the limit."
      exit 4
    fi
    sleep 5; waited=$((waited + 5))
  done
  wait "$bpid" || { echo "pb-ci: the image build failed (builder $builder). Run: BUILDX_BUILDER=$builder docker build -t $image <pb-ci skill folder> to see why."; exit 4; }
fi

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
