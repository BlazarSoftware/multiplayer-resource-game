# Creature Crafting Demo - Dedicated Server
# Exports the game using pre-built Mechanical Turk engine binaries (Godot 4.7 fork)
#
# Prerequisites:
#   Run ./scripts/build-engine-templates.sh first to compile the MT engine for Linux.

# --- Build stage: export the server binary ---
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built MT engine binaries (built by build-engine-templates.sh)
COPY engine-builds/linux/godot-editor /usr/local/bin/godot
COPY engine-builds/linux/godot-template /tmp/godot-template
RUN chmod +x /usr/local/bin/godot

# Install export template in the location MT engine expects
# MT uses "mechanical_turk" as its data dir (from version.py short_name)
# Version string: 4.7.dev (major.minor.status from engine's version.py)
RUN mkdir -p "/root/.local/share/mechanical_turk/export_templates/4.7.dev" \
    && cp /tmp/godot-template "/root/.local/share/mechanical_turk/export_templates/4.7.dev/linux_release.x86_64" \
    && cp /tmp/godot-template "/root/.local/share/mechanical_turk/export_templates/4.7.dev/linux_debug.x86_64" \
    && rm /tmp/godot-template

# Copy project files
WORKDIR /project
COPY . .

# Import resources (needed before export)
RUN godot --headless --import 2>/dev/null || true

# Export the server build
RUN mkdir -p builds/server \
    && godot --headless --export-release "Linux Server" builds/server/creature_crafting_server.x86_64

# --- Runtime stage: slim image with just the binary ---
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libgl1 libglu1-mesa libasound2 libpulse0 coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /project/builds/server/creature_crafting_server.x86_64 .
RUN mkdir -p /app/data/players

EXPOSE 7777/udp

# Use stdbuf to force line-buffered stdout so docker logs works
CMD ["stdbuf", "-oL", "./creature_crafting_server.x86_64", "--headless"]
