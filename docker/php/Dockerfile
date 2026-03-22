FROM php:8.3-fpm

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl unzip \
    libicu-dev \
    libzip-dev zip \
    libpng-dev libjpeg-dev libwebp-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions required by Symfony
RUN docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install \
        intl \
        pdo_mysql \
        opcache \
        zip \
        gd \
        sodium \
        bcmath

# Xdebug (dev only — disable in production by removing this block)
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

COPY xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
COPY php.ini /usr/local/etc/php/conf.d/app.ini

# Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
