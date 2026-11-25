#!/bin/bash
# Make sure Docker is running: if `docker info` fails, start Docker Desktop (open -g -a Docker) and wait until it answers.
# Sessions may start Docker themselves; no need to ask the user (owner's decision of 2026-11-25).
# Env: PBCI_DOCKER_WAIT (seconds, default 180), PBCI_DOCKER_POLL (seconds, default 3),
#      PBCI_UNAME (tests only: overrides uname -s).
# Exit 0 Docker ready, 4 Docker cannot be started or is not ready in time.
set -u
# docker_ok: `docker info` with a hard limit of 10 s per call, so a hanging CLI cannot stretch the wait.
docker_ok() {
  docker info >/dev/null 2>&1 &
  local p=$! t=0
  while kill -0 "$p" 2>/dev/null; do
    if [ "$t" -ge 10 ]; then kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 1; fi
    sleep 1; t=$((t + 1))
  done
  wait "$p"
}
docker_ok && exit 0
os="${PBCI_UNAME:-$(uname -s 2>/dev/null)}"
if [ "$os" != Darwin ]; then
  echo "pb-ci: Docker is not running, and this is not macOS: start the Docker daemon (for example 'sudo systemctl start docker') and rerun."
  exit 4
fi
command -v open >/dev/null 2>&1 || { echo "pb-ci: Docker is not running, and this Mac has no 'open' command: start Docker Desktop, then rerun."; exit 4; }
wait_s="${PBCI_DOCKER_WAIT:-180}"; poll="${PBCI_DOCKER_POLL:-3}"
echo "pb-ci: Docker is not running; starting Docker (open -g -a Docker) and waiting up to ${wait_s}s."
open -g -a Docker || { echo "pb-ci: 'open -a Docker' failed: is Docker Desktop installed?"; exit 4; }
start=$SECONDS
while [ $((SECONDS - start)) -lt "$wait_s" ]; do
  docker_ok && { echo "pb-ci: Docker is ready after $((SECONDS - start))s."; exit 0; }
  sleep "$poll"
done
echo "pb-ci: Docker is not ready after ${wait_s}s. Check Docker Desktop, then rerun (PBCI_DOCKER_WAIT=<seconds> changes the wait)."
exit 4
