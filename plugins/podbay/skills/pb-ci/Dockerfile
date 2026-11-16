# Local CI image for Pod Bay. Rust is pinned: the repo has no rust-toolchain file or rust-version,
# so this matches the compiler the team builds with. Change it together with layout.sh.
FROM rust:1.99.1-slim-trixie

# git: build.rs reads the commit. tmux: mesh tests. curl: the updater and its tests. X11/Wayland/GL/xkbcommon: eframe and egui_kittest.
# mesa-vulkan-drivers: software GPU (lavapipe) for wgpu if a test needs one.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git tmux pkg-config \
      libxkbcommon-dev libwayland-dev libx11-dev libxcursor-dev libxrandr-dev libxi-dev \
      libgl1-mesa-dev libegl1-mesa-dev mesa-vulkan-drivers libvulkan1 \
 && rm -rf /var/lib/apt/lists/* \
 && rustup component add clippy \
 && git config --system --add safe.directory '*'

ENV CARGO_TARGET_DIR=/target PODBAY_ENV=local CARGO_TERM_COLOR=never
WORKDIR /src
