#!/bin/bash
set -e

PROJECT_NAME="${1:?Usage: $0 <project-name> [language]}"
LANGUAGE="${2:-en}"

# Configure ddev
ddev config --project-type=drupal --php-version=8.3 --docroot=web --project-name="$PROJECT_NAME"

# Start ddev
ddev start

# Download Drupal 11 into a temp directory to avoid conflicts with existing files
ddev exec mkdir -p /tmp/drupal-temp
ddev exec composer create-project "drupal/recommended-project:^11" /tmp/drupal-temp --no-install

# Move all Drupal files (including dotfiles) into the project root
ddev exec bash -c 'shopt -s dotglob && cp -r /tmp/drupal-temp/* /var/www/html/ && rm -rf /tmp/drupal-temp'

# Ignore known security advisory for symfony/process (required by drupal/core-recommended)
ddev composer config audit.ignore "PKSA-rkkf-636k-qjb3"

# Install composer dependencies
ddev composer install

# Install Drush
ddev composer require drush/drush

# Install Drupal site
ddev drush site:install standard \
  --site-name="$PROJECT_NAME" \
  --locale="$LANGUAGE" \
  --account-name=admin \
  --account-pass=admin \
  --yes

# Show status
ddev drush status

echo ""
echo "=== Setup complete ==="
echo "URL: $(ddev describe -j | php -r 'echo json_decode(file_get_contents("php://stdin"))->raw->httpurl;' 2>/dev/null || echo "Run 'ddev describe' to check the URL")"
echo "Username: admin"
echo "Password: admin"
