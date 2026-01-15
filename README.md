# Hytale Server Docker Image

Lightweight Docker image and helper entrypoint to run a Hytale server with automated token handling for the official Hytale provider authentication flow.

**What it does:**
- Builds a Docker image that can download Hytale server files (via the official downloader) and launch the server jar.
- Supports automated device-code (RFC 8628) authentication when enabled, and stores downloader/session tokens on disk for reuse.

**Files of interest:**
- `Dockerfile` — image build (Debian/Temurin base with downloader).
- `entrypoint.sh` — container entrypoint: handles auth, downloader invocation and server launch.
- `docker-compose.example.yaml` — example compose file with env placeholders.

**Environment variables**
- **HYTALE_AUTOMATE_DEVICE_FLOW**: `0|1` — when `1`, the container will run the Device Code flow to obtain OAuth tokens if downloader credentials are missing or expired.
- **HYTALE_CLIENT_ID**: OAuth client id (defaults to `hytale-server`).
- **HYTALE_SCOPE**: OAuth scope (defaults to `openid offline auth:server`).
- **HYTALE_PATCHLINE**: Patchline / branch for the downloader (defaults to `release`).
- **DOWNLOADER_BIN**: Path to the hytale downloader binary inside the container (override only if you replace the binary).
- **HYTALE_SERVER_SESSION_TOKEN** / **HYTALE_SERVER_IDENTITY_TOKEN**: Provide existing session tokens to run headless (skip device flow).
- **HYTALE_SKIP_UPDATE_CHECK**: `0|1` — set to `1` to skip invoking the downloader.
- **HYTALE_SERVER_ADDITIONAL_ARGS**: Extra JVM / server args appended to the Java command.

Note: Credentials are persisted under the container path `/opt/hytale/tokens/.hytale-downloader-credentials.json` and session tokens in `/opt/hytale/tokens/session_tokens.json` (these are mounted from your host when you map `./data` or similar).

**Example — docker run**
1) Create host dirs for persistence:

```bash
mkdir -p ./data/tokens ./data/server
```

2) Run the container (interactive flow allowed):

```bash
docker run --rm -it \
  -v "$(pwd)/data/server:/opt/hytale/server" \
  -v "$(pwd)/data/tokens:/opt/hytale/tokens" \
  -e HYTALE_AUTOMATE_DEVICE_FLOW=1 \
  -e HYTALE_PATCHLINE=release \
  hytale-server:latest
```

3) Run headless with pre-provisioned tokens (example):

```bash
export HYTALE_SERVER_SESSION_TOKEN="<session-token>"
export HYTALE_SERVER_IDENTITY_TOKEN="<identity-token>"
docker run --rm -d \
  -v "$(pwd)/data/server:/opt/hytale/server" \
  -v "$(pwd)/data/tokens:/opt/hytale/tokens" \
  -e HYTALE_PATCHLINE=release \
  hytale-server:latest
```

**Example — docker compose**
Use the provided `docker-compose.example.yaml` as a starting point. Basic example:

```yaml
services:
    image: ghcr.io/daranix/hytale-server-docker:1.0.0
    ports:
      - "5520:5520/udp"
    volumes:
      - ./data/server:/opt/hytale/server
      - ./data/tokens:/opt/hytale/tokens
    environment:
      - HYTALE_AUTOMATE_DEVICE_FLOW=1
      - HYTALE_PATCHLINE=release
    restart: unless-stopped
```

Replace `HYTALE_AUTOMATE_DEVICE_FLOW=1` with `0` and supply `HYTALE_SERVER_SESSION_TOKEN`/`HYTALE_SERVER_IDENTITY_TOKEN` if you want the container to run without interactive authorization.

**Notes on tokens & auth**
- The downloader credentials file looks like:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_at": 1768341836,
  "branch": "release"
}
```

- The container performs the Device Code Flow per Hytale's Server Provider Authentication Guide (Method B). See:
  - https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide#method-b-device-code-flow-rfc-8628-
  - https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual

**Contributing / Pull Requests**
- PRs are welcome — please open pull requests to improve the image, Dockerfile, `entrypoint.sh`, or documentation. Aim for small, well-tested changes and update this `README.md` when adding or changing environment variables or behavior.

**License / Disclaimer**
- This project is a community-built helper image for running the Hytale server. Follow Hytale's official documentation and terms when running public servers. This repository is not affiliated with Hytale / Hypixel Studios.

