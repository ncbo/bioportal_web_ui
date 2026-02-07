#!/bin/bash
set -e

# 1. Validate required environment variables
if [ -z "$BIOPORTAL_API_KEY" ]; then
  echo "ERROR: BIOPORTAL_API_KEY environment variable is required"
  echo "Usage: docker run -e BIOPORTAL_API_KEY=your_key -e DB_PASSWORD=your_pass ..."
  exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: DB_PASSWORD environment variable is required"
  echo "Usage: docker run -e BIOPORTAL_API_KEY=your_key -e DB_PASSWORD=your_pass ..."
  exit 1
fi

# 2. Start services
echo "Starting memcached..."
sudo /etc/init.d/memcached start

echo "Starting mariadb..."
sudo /etc/init.d/mariadb start
sleep 2  # Give mariadb time to initialize

# 3. Configure database access
echo "Configuring database..."
sudo mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASSWORD');"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# 4. Generate config files from templates
echo "Generating config files..."
mkdir -p config
envsubst '${DB_PASSWORD}' < /opt/templates/database.yml.template > config/database.yml
envsubst '${BIOPORTAL_API_KEY}' < /opt/templates/bioportal_config_development.rb.template > config/bioportal_config_development.rb
cp /opt/templates/Procfile.dev Procfile.dev

# 5. Install dependencies
echo "Installing node packages..."
npm install yarn
./node_modules/.bin/yarn install

echo "Installing gems..."
sudo bundler install

# 6. Setup database
echo "Setting up database..."
sudo rails db:setup

# 7. Start dev server
echo "Starting development server..."
exec sudo ./bin/dev
