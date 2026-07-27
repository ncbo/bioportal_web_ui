# Run BioPortal Web UI Locally

This repo is set up to run the UI via Docker Compose. These steps mirror the recommended workflow in the scripts.

## Prereqs

- Docker
- Docker Compose

## Quick Start (Docker)

1. Create the env file if it does not exist:

```bash
cp .env.sample .env
```

2. Edit `.env` and set the API settings you want to use:

- `API_URL`
- `API_KEY`

3. Optional: start a local API (default `http://localhost:9393`):

```bash
bin/run_api
```

4. Start the UI:

```bash
bin/ontoportal dev
```

Or pass API values explicitly:

```bash
bin/ontoportal dev --api-url http://localhost:9393 --api-key YOUR_KEY
```

5. Open the UI:

- `http://localhost:3000`

## Notes

- `bin/ontoportal dev` will run `rails credentials:edit` inside the container using `nano`. Exit when done.
- If you hit `Couldn't decrypt config/credentials/development.yml.enc`, you may need the matching key (`config/credentials/development.key` or `RAILS_MASTER_KEY`). If you do not have it, you can remove `config/credentials/development.yml.enc` (and any existing `development.key`) and re-create credentials, then rerun `bin/ontoportal dev`.
- Stop everything:

```bash
docker compose down
```

- Reset Docker volumes/cache:

```bash
bin/ontoportal dev --reset-cache
```

## Non-Docker Setup

This is a best-effort local setup based on repo configuration. It assumes you have local MySQL and Memcached.

### Prereqs

- Ruby `3.2.9` (see `.ruby-version`)
- Bundler (`gem install bundler` if needed)
- Node.js `20.x` and Yarn `1.x`
- MySQL `8.x` (or compatible)
- Memcached

### Setup

1. Create config files if they do not exist:

```bash
cp .env.sample .env
cp config/bioportal_config_env.rb.sample config/bioportal_config_development.rb
cp config/database.yml.sample config/database.yml
```

2. Edit `.env` and set at least:

- `API_URL`
- `API_KEY`

If you are running MySQL locally, set `DB_HOST=localhost` (the sample file expects `DB_HOST`).

3. Install Ruby and JS deps:

```bash
bundle install
yarn install
```

4. Prepare the database:

```bash
bin/rails db:prepare
```

5. Start assets build (separate terminal):

```bash
yarn build --watch
```

6. Start the Rails server (separate terminal):

```bash
bin/rails server -p 3000
```

7. Open the UI:

- `http://localhost:3000`

### Notes

- If you need a local API for testing, you can still run `bin/run_api` (it uses Docker).
- `bin/dev` uses `foreman` + `Procfile.dev` but does **not** load `.env` (`--env /dev/null`). If you use it, export env vars first (or use separate terminals as above).
- If Rails complains about missing credentials or master key, run:

```bash
bin/rails credentials:edit
```
