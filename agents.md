# Agents Guide

## Quick Start
1. Start server:
   - `./start-docker-server.sh`
2. Launch client with Mechanical Turk and open this project.
3. Join using `127.0.0.1`.

## Networking Contract
- Server/client default UDP port is `7777`.
- Any tooling, scripts, docs, and deployment defaults should assume `7777`.

## Multiplayer Expectations
- Server is authoritative for world state and movement simulation.
- Client must complete world-load readiness before spawn replication begins.
- If join fails, inspect logs for readiness/replication errors first.

## UI/UX Expectations
- Battle encounters must show mouse cursor for UI interaction.
- Exiting battle should recapture mouse for movement/camera control.
- Wild encounter areas should be clearly visible in-world and explained via HUD hinting.

## Operational Notes
- If container/server appears stale, rebuild:
  - `docker compose up --build -d`
- If needed, force rebuild without cache:
  - `docker compose build --no-cache`
  - `docker compose up -d`
