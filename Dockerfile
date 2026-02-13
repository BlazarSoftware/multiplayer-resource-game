# Creature Crafting Demo - Dedicated Server
# Builds a headless Godot 4.6 server in a Docker container

ARG GODOT_VERSION=4.6
ARG GODOT_RELEASE=stable

# --- Build stage: export the server binary ---
FROM ubuntu:22.04 AS builder

ARG GODOT_VERSION
ARG GODOT_RELEASE

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download Godot headless and export templates
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip \
    -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp \
    && mv /tmp/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz \
    -O /tmp/templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE} \
    && unzip /tmp/templates.tpz -d /tmp/templates \
    && mv /tmp/templates/templates/* /root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}/ \
    && rm -rf /tmp/templates /tmp/templates.tpz

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
