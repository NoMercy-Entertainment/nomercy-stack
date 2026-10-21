# syntax=docker/dockerfile:1
FROM php:8.5.12-fpm-alpine3.24
LABEL Maintainer="Stoney Eagle <stoney@nomercy.tv>"
LABEL Description="Lightweight container with Nginx 1.26 & PHP 8.5 based on the official PHP Alpine image."

# Setup document root
WORKDIR /var/www/html

RUN adduser -D -g '' www sudo

ARG PHP_EXPECTED=8.5.12

# Install packages (nginx, supervisor, the build toolchain for assets, and the libraries the PHP extensions load)
RUN apk add --no-cache \
  curl \
  nginx \
  bash \
  git \
  htop \
  imagemagick \
  libcurl \
  libwebp-dev \
  libzip-dev \
  nano \
  npm \
  openjpeg \
  openssh-client \
  patch \
  supervisor \
  texinfo \
  wget \
  yarn \
  zlib \
  icu-libs \
  libpng \
  libjpeg-turbo \
  freetype \
  libwebp \
  libzip \
  libpq

# PHP extensions the official image does not ship. It already has ctype, curl, dom, fileinfo, iconv, mbstring,
# openssl, pdo_sqlite, phar, session, simplexml, sodium, sqlite3, tokenizer, xml, xmlreader, xmlwriter and OPcache.
RUN apk add --no-cache --virtual .php-build-deps $PHPIZE_DEPS icu-dev libpng-dev libjpeg-turbo-dev freetype-dev \
    libwebp-dev libzip-dev postgresql-dev linux-headers \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" bcmath ftp gd intl mysqli pdo_mysql pdo_pgsql zip \
 && apk del .php-build-deps

# Refuse an image whose PHP is not the version we patched to.
RUN test "$(php -r 'echo PHP_VERSION;')" = "${PHP_EXPECTED}" || { echo "PHP is $(php -r 'echo PHP_VERSION;'), expected ${PHP_EXPECTED}"; exit 1; }

# Configure nginx - http
COPY config/nginx.conf /etc/nginx/nginx.conf
# Configure nginx - default server
COPY config/conf.d /etc/nginx/conf.d/

# Configure PHP-FPM (PHP_INI_DIR is /usr/local/etc/php in the official image). supervisord starts php-fpm with
# only our pool file, so the image's zz-docker.conf (listen = 9000) never replaces our unix socket.
ENV php_ini=${PHP_INI_DIR}/php.ini
ENV fpm_conf=/usr/local/etc/php-fpm.d/www.conf

COPY config/fpm-pool.conf ${fpm_conf}
COPY config/php.ini ${php_ini}

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the www user
RUN chown -R www:www /var/www/html /run /var/lib/nginx /var/log/nginx

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Which host checkout to bake in — "data" (default) or "data-green" for the
# blue-green idle color. See website-compose.yml (website-blue/website-green).
ARG DATA_DIR=data

# Copy application code and install dependencies at build time
COPY --chown=www ./${DATA_DIR}/ /var/www/html/
RUN --mount=type=cache,target=/tmp/composer-cache,uid=1000 \
    su -s /bin/bash www -c "COMPOSER_CACHE_DIR=/tmp/composer-cache composer install --working-dir=/var/www/html --no-interaction --optimize-autoloader"
RUN su -s /bin/bash www -c "cd /var/www/html && yarn && yarn build"

# Stash pre-built deps + compiled Vite assets outside the volume/bind-mount
# points so start.sh can restore them at runtime (the vendor/node_modules
# volumes and the ./data* bind mount shadow the image copies). Baking the asset
# build here — and restoring it at boot instead of rebuilding — keeps the
# memory-heavy `yarn build` off the production host, where it was OOM-killing
# the blue-green deploy.
RUN cp -a /var/www/html/vendor /opt/_vendor_built \
 && cp /var/www/html/composer.lock /opt/_vendor_built.lock \
 && cp -a /var/www/html/node_modules /opt/_node_modules_built \
 && cp -a /var/www/html/public/build /opt/_public_build_built

# Expose the port nginx is reachable on
ADD config/start.sh /start.sh
RUN chmod 755 /start.sh

ADD config/resolv.conf /etc/resolv.conf

EXPOSE 8080

RUN sed -i -e 's/\r$//' /start.sh

CMD ["/start.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
