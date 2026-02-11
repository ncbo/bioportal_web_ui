# CLAUDE.md - BioPortal Web UI

This file provides context for AI assistants working with this codebase.

## Project Overview

BioPortal Web UI is a Ruby on Rails application for browsing and interacting with biological ontologies. It is the frontend for the BioPortal/OntoPortal platform and communicates with an independent REST API for almost all data.

- **Live site**: https://bioportal.bioontology.org/
- **Repository**: https://github.com/ncbo/bioportal_web_ui
- **Development guide**: See `developer/` directory and setup instructions below

## Tech Stack

- **Framework**: Rails 8.0.3
- **Ruby**: 3.2.9 (see `.ruby-version`)
- **Database**: MySQL 8.0 (MariaDB compatible for dev)
- **Cache**: Memcached
- **JavaScript**: ES modules via esbuild, Hotwire (Turbo + Stimulus)
- **CSS**: Bootstrap 5.2, Dart Sass
- **Template Engine**: Haml
- **View Components**: ViewComponent + Lookbook

## Development Setup (Docker - Recommended)

Uses the `bioportal-dev` Docker image built from the `developer/` directory in this repo.

### Prerequisites

1. Access to a BioPortal/OntoPortal API server (contact a current developer)
2. Your API key from the API server's account page

### Build the Docker Image (once)

From the `bioportal_web_ui` directory:

```bash
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) \
  -t bioportal-dev -f developer/Dockerfile.developer-environment developer/
```

### Run the Development Environment

From the `bioportal_web_ui` directory:

```bash
docker run --name bpd --network host -it --rm \
  -e BIOPORTAL_API_KEY=your_api_key_here \
  -e BIOPORTAL_API_URL=https://your-api-server \
  -e BIOPORTAL_PROXY_URL=http://your-annotator-proxy \
  -e BIOPORTAL_LEGACY_REST_URL=http://your-legacy-rest \
  -e DB_PASSWORD=choose_any_password \
  -v $(pwd):/home/developer/bioportal_web_ui \
  bioportal-dev
```

The container automatically:
- Starts memcached and mariadb
- Configures database with your password
- Generates config files (`database.yml`, `bioportal_config_development.rb`)
- Installs dependencies (yarn, bundler)
- Sets up the database
- Launches the dev server at http://localhost:3000

First run takes a few minutes. Subsequent runs are faster.

### Stopping

Press `Ctrl+C` to stop the dev server and exit the container.

## Development Notes

- The database resets each time the container is removed
- Most JS and Ruby file changes hot-reload; config files require container restart
- The staging server could be reset at any time
- Some pages require admin access (admin protected)
- Dev uses Ruby 3.2.3 in container vs 3.2.9 in production - no issues so far
- MariaDB in dev is compatible with MySQL 5.7.44 target

## Alternative: docker-compose (from repo)

The repository also includes a `docker-compose.yml` for an alternative setup:

```bash
cp .env.sample .env
# Edit .env with API_URL and API_KEY
docker compose up dev
```

Services: `dev` (Rails), `node` (JS watcher), `db` (MySQL 8.0), `cache` (Memcached)

## Testing

Both Minitest and RSpec are used. Tests must run inside the Docker container
with `sudo` (because the entrypoint configures services as root).

**Important**: Most tests make live HTTP calls to the configured API server
(`$REST_URL`), which can be slow (5-30s per call). Tests will appear to hang
after `# Running:` — this is normal; wait 1-2 minutes for the first dots to
appear. Use `-v` for verbose output showing test names as they start.

### Running in the Docker container

```bash
# Enter a running container
docker exec -it bpd bash

# Minitest (test/ directory)
sudo RAILS_ENV=test bin/rails test
sudo RAILS_ENV=test bin/rails test test/controllers/ontologies_controller_test.rb

# RSpec (spec/ directory)
sudo RAILS_ENV=test bundle exec rspec
sudo RAILS_ENV=test bundle exec rspec spec/models/

# System tests (headless Chrome, installed in dev container)
sudo RAILS_ENV=test bin/rails test:system
```

### System tests with docker-compose (remote Selenium)

The `docker-compose.yml` includes a `chrome-server` service for running system
tests via a standalone Selenium container. To use it instead of the dev
container's local Chrome, set `SELENIUM_URL` in the test service's environment:

```yaml
  test:
    environment:
      SELENIUM_URL: "http://localhost:4444"
```

Then run:
```bash
docker compose run test bin/rails test:system
```

### Environment variables

- `ONTOLOGIES_TO_TEST=STY` — limits ontologies controller tests to a single
  ontology instead of fetching the entire catalog from the API (recommended)
- `TEST_TIMEOUT=300` — per-test timeout in seconds (default: 180); tests that
  exceed this are reported as skips, not failures
- `SELENIUM_URL` — when set, system tests use a remote Selenium server at this
  URL instead of local headless Chrome (e.g. `http://localhost:4444`)

### Notes

- The session store uses `CacheStore` (memcached), so the test environment
  needs `config.cache_store = :memory_store` (not `:null_store`) for flash
  and session data to persist across redirects
- `IssueCreatorService` specs require a GitHub token in Rails credentials
  (`kgcl:github_access_token`); they skip gracefully when absent
- `sudo` strips `PATH`; if you need yarn under sudo, install it globally
  first: `sudo npm install -g yarn`

## Key Directories

```
app/
├── components/     # ViewComponent classes
├── controllers/    # Rails controllers
├── helpers/        # View helpers
├── javascript/     # Stimulus controllers, ES modules
├── models/         # ActiveRecord models, API wrappers
├── views/          # Haml templates
config/
├── bioportal_config_*.rb  # Environment-specific BioPortal settings
├── database.yml           # Database configuration
├── routes.rb              # URL routing
developer/          # Dockerfile, entrypoint, and config templates for dev container
public/browse/      # Legacy Angular browse application
spec/               # RSpec tests
test/               # Minitest tests
```

## Configuration

### Key Config Files

- `config/bioportal_config_development.rb` - Portal settings, API key, feature flags
- `config/database.yml` - Database connection settings

### Important Variables

- `$API_KEY` - BioPortal API authentication key
- `$REST_URL` - BioPortal REST API URL (set via `BIOPORTAL_API_URL` env var)
- `$UI_URL` - This application's URL
- `$SITE` / `$ORG` - Site name and organization

## Code Style

- Ruby: RuboCop (`bundle exec rubocop`)
- JavaScript: ESLint + Prettier (`yarn lint`, `yarn lint:fix`)
- Security: Brakeman (`bundle exec brakeman`)

## Useful Links

- API Client: https://github.com/ncbo/ontologies_api_ruby_client
- Architecture diagram: https://github.com/berkeleybop/bioportal-development-guide/blob/main/files/BioPortal_Architecture.pdf
