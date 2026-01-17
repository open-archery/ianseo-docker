ARG PHP_EXTENSIONS="gd mysqli imagick intl"

FROM thecodingmachine/php:8.5-v5-slim-apache

ENV PHP_INI_MAX_EXECUTION_TIME=240 \
    PHP_INI_MEMORY_LIMIT=512M \
    PHP_INI_POST_MAX_SIZE=128M \
    PHP_INI_UPLOAD_MAX_FILESIZE=128M

ARG IANSEO_URL="https://www.ianseo.net/Release/Ianseo_20250210.zip"

RUN curl -fsSL "${IANSEO_URL}" -o /tmp/ianseo.zip; \
    unzip -q /tmp/ianseo.zip -d /var/www/html; \
    rm /tmp/ianseo.zip;
