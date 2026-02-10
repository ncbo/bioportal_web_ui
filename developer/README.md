# BioPortal Developer Environment

Docker-based development environment for the
[BioPortal Web UI](https://github.com/ncbo/bioportal_web_ui).

For full setup instructions and project context, see
[CLAUDE.md](../CLAUDE.md) in the repository root.

## Contents

- `Dockerfile.developer-environment` — Docker image definition (Ubuntu Noble + Ruby, Node, MariaDB, Chrome, etc.)
- `entrypoint.sh` — Container entrypoint that starts services, generates configs, and launches the dev server
- `database.yml.template` — Database config template (substitutes `$DB_PASSWORD`)
- `bioportal_config_development.rb.template` — BioPortal config template (substitutes `$BIOPORTAL_API_KEY`, `$BIOPORTAL_API_URL`, `$BIOPORTAL_PROXY_URL`, `$BIOPORTAL_LEGACY_REST_URL`)
- `Procfile.dev` — Foreman process definitions for the dev server

## Quick Start

From the `bioportal_web_ui` root:

```bash
# Build the image (once)
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) \
  -t bioportal-dev -f developer/Dockerfile.developer-environment developer/

# Run the dev environment
docker run --name bpd --network host -it --rm \
  -e BIOPORTAL_API_KEY=your_api_key_here \
  -e BIOPORTAL_API_URL=https://your-api-server \
  -e BIOPORTAL_PROXY_URL=http://your-annotator-proxy \
  -e BIOPORTAL_LEGACY_REST_URL=http://your-legacy-rest \
  -e DB_PASSWORD=choose_any_password \
  -v $(pwd):/home/developer/bioportal_web_ui \
  bioportal-dev
```
