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

# Run all Laravel production optimizations
su -s /bin/bash www -c "cd /var/www/html && php artisan optimize:production"

# Start supervisord and services (must be last — exec replaces the shell)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
