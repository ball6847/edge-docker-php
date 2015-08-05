#!/bin/bash
set -e

NGINX_VERSION=1.9.3
NPS_VERSION=1.9.32.6
PHP_VERSION=7.0.0beta2

DEBIAN_FRONTEND=noninteractive

# build apt cache
apt-get update

# install basic tools
apt-get install -y --no-install-recommends build-essential msmtp-mta python-pip=1.5.4-1 curl nano wget git-core ca-certificates supervisor
pip install j2cli

# download ngx_pagespeed
apt-get install -y --no-install-recommends zlib1g-dev libpcre3-dev libssl-dev
mkdir /tmp/ngx_pagespeed
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.tar.gz -O - | tar -zxf - --strip=1 -C /tmp/ngx_pagespeed
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz -O - | tar -zxf - -C /tmp/ngx_pagespeed

# install nginx
mkdir /tmp/nginx
mkdir /var/www
mkdir -p /etc/nginx/conf.d
mkdir -p -m 755 /var/cache/pagespeed
chown -R www-data:www-data /var/cache/pagespeed /var/www
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O - | tar -zxf - -C /tmp/nginx --strip=1
cd /tmp/nginx
./configure \
    --prefix=/etc/nginx/ \
    --conf-path=/etc/nginx/nginx.conf \
    --sbin-path=/usr/sbin/nginx \
    --user=www-data \
    --group=www-data \
    --with-http_ssl_module \
    --with-http_spdy_module \
    --add-module=/tmp/ngx_pagespeed
make -j"$(nproc)"
make install

# create custom dh params
openssl dhparam -out /etc/ssl/certs/dhparam-reduced.pem 1024
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# download and install php
apt-get install -y --no-install-recommends libcurl4-openssl-dev libreadline6-dev libmcrypt-dev libxml2-dev libpng-dev libjpeg-turbo8-dev libicu-dev
mkdir /tmp/php
mkdir -p /usr/local/etc/php/conf.d
wget https://downloads.php.net/~ab/php-$PHP_VERSION.tar.bz2 -O - | tar -jxf - -C /tmp/php --strip=1
cd /tmp/php
./configure \
    --with-config-file-path=/usr/local/etc/php \
    --with-config-file-scan-dir=/usr/local/etc/php/conf.d \
    --with-jpeg-dir=/usr \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --disable-cgi \
    --enable-fpm \
    --enable-intl \
    --enable-mbstring \
    --enable-mysqlnd \
    --enable-opcache \
    --enable-soap=shared \
    --enable-zip \
    --with-curl \
    --with-openssl \
    --with-readline \
    --with-zlib \
    --with-pdo-mysql \
    --with-mcrypt=shared \
    --with-gd=shared
make -j"$(nproc)"
make install

# install composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# cleanup
apt-get purge -y build-essential g++
apt-get autoremove -y
apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
