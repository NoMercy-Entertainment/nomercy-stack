#!/bin/bash
set -e

# Restore the optimized vendor tree baked into the image over the named volume,
# which persists (and can go stale) across recreates. Done unconditionally — a
# cheap cp — so the freshly-built --no-cache image's autoload always wins and we
# never have to run composer on the memory-constrained live host (that was
# OOM-killing the deploy). node_modules is intentionally NOT restored: it is
# only needed to BUILD assets, which now happens at image-build time, so the
# runtime container never needs it.
if [ -d /opt/_vendor_built ]; then
    echo "Restoring vendor from build cache..."
    rm -rf /var/www/html/vendor
    mkdir -p /var/www/html/vendor
    cp -a /opt/_vendor_built/. /var/www/html/vendor/
    chown -R www:www /var/www/html/vendor
fi

# Restore the compiled Vite assets baked into the image over the bind-mounted
# checkout, which ships without public/build (it is gitignored and never built
# on the host). Restoring the image build instead of running `yarn build` at
# boot keeps the memory-heavy asset build off the live host — running it there,
# alongside the other color and the rest of the stack, was OOM-killing the
# deploy. The image is rebuilt --no-cache from the exact deployed commit, so
# these assets always match the code being served.
if [ -d /opt/_public_build_built ]; then
    echo "Restoring compiled assets from build cache..."
    rm -rf /var/www/html/public/build
    mkdir -p /var/www/html/public/build
    cp -a /opt/_public_build_built/. /var/www/html/public/build/
fi

# The idle-color checkout is a bind mount owned by the host deploy user, not
# www. git refuses to operate on a foreign-owned repo ("detected dubious
# ownership") and www cannot write Laravel's compiled caches or Vite's build
# output — so a freshly cloned checkout (notably the first green deploy) fails
# composer dump-autoload / artisan optimize / yarn build with permission errors.
# Mark the repo safe for every user and hand www the directories it writes.
git config --system --add safe.directory /var/www/html
chown -R www:www \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache \
    /var/www/html/public
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

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
