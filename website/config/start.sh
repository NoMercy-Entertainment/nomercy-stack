#!/bin/bash
set -e

# Sync pre-built dependencies from image into volumes (fast cp vs slow install)
# The named volumes mount empty on first run, overriding the image contents
if [ ! -f /var/www/html/vendor/autoload.php ]; then
    echo "Syncing vendor from build cache..."
    chown -R www:www /var/www/html/vendor
    cp -a /opt/_vendor_built/. /var/www/html/vendor/
fi

if [ ! -d /var/www/html/node_modules/.cache ] && [ -d /opt/_node_modules_built ]; then
    echo "Syncing node_modules from build cache..."
    chown -R www:www /var/www/html/node_modules
    cp -a /opt/_node_modules_built/. /var/www/html/node_modules/
fi

# Ensure storage is writable by PHP-FPM (www user)
chown -R www:www /var/www/html/storage
chmod -R 775 /var/www/html/storage

# auth.json holds composer registry credentials (a 0600 secret). It arrives via
# the root-owned host bind mount, which the www user that runs composer cannot
# read, so composer aborts before dump-autoload. Normalize ownership to www while
# keeping it non-world-readable.
if [ -f /var/www/html/auth.json ]; then
    chown www:www /var/www/html/auth.json
    chmod 600 /var/www/html/auth.json
fi

# Apply pending migrations on boot. DB is ready (depends_on mysql healthy) and the
# app code is the freshly reset bind mount. set -e means a bad migration fails the
# container start loudly instead of serving a green deploy on a stale schema.
su -s /bin/bash www -c "cd /var/www/html && php artisan migrate --force"

# Run all Laravel production optimizations
su -s /bin/bash www -c "cd /var/www/html && php artisan optimize:production"

# Start supervisord and services (must be last — exec replaces the shell)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
