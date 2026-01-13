# Hytale server Docker setup (device-code / headless notes)

This workspace contains a Dockerfile and `docker-compose.yml` to build an image based on Eclipse Temurin 25 (Alpine) that downloads the official Hytale downloader and provides an entrypoint to run the device-code (METHOD B) flow and start a server.

Files added:
- `Dockerfile` — builds image, downloads/unzips the Hytale downloader into `/opt/hytale/downloader`.
- `entrypoint.sh` — optional automation for METHOD B device code flow. When `HYTALE_AUTOMATE_DEVICE_FLOW=1` it will:
  - Request a device code from `https://oauth.accounts.hytale.com/oauth2/device/auth`.
  - Print the verification URL and user code (or direct verification URL).
  - Poll `https://oauth.accounts.hytale.com/oauth2/token` until authorization completes.
  - Call `GET /my-account/get-profiles` and `POST /game-session/new` to obtain `sessionToken` and `identityToken`.
  - Persist tokens to `/opt/hytale/server/oauth_tokens.json` and `/opt/hytale/server/session_tokens.json` and export `HYTALE_SERVER_SESSION_TOKEN` and `HYTALE_SERVER_IDENTITY_TOKEN` for the running process.
- `docker-compose.yml` — builds the image and mounts the local `Server/` directory into the container at `/opt/hytale/server`.

Usage:

1. Ensure the `Server/` folder contains your Hytale server binary (e.g. `HytaleServer.aot` or a `*.jar`).
2. Build & run with docker-compose:

```bash
docker compose up --build
```

Notes on headless device-code flow:
- The device-code flow still requires a human to visit the printed `verification_uri_complete` and approve the device on accounts.hytale.com. The container will poll and resume automatically after authorization.
- For fully automated provisioning of many servers, perform the device-code flow once (on a management host) to obtain a `refresh_token`, then store & distribute refresh/session tokens to server instances via environment variables or mounted files (see METHOD C and token passthrough in the Hytale docs).
- Tokens persisted under `Server/` (mounted volume) survive restarts. You can pre-populate `Server/session_tokens.json` with existing `sessionToken`/`identityToken` to skip device flow.

Security:
- Protect `oauth_tokens.json` and `session_tokens.json` — they contain sensitive tokens.
- Prefer using an external secure credential store for production.

References:
- Server Provider Authentication Guide — Method B (device code flow): https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide#method-b-device-code-flow-rfc-8628
