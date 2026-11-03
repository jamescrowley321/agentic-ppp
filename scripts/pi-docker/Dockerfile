# pi for ppp-run.sh --docker. The container gets the worktree at /workspace
# and the key as an environment variable; nothing from the host's ~/.pi.
# Build: docker build -t agentic-ppp/pi:latest scripts/pi-docker
FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep jq \
  && rm -rf /var/lib/apt/lists/*
# Pinned to the pi version the host runs, so a result here matches host mode.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@1.2.0

WORKDIR /workspace
ENTRYPOINT []
