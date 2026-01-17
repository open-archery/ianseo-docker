ARG PHP_EXTENSIONS="gd mysqli imagick intl"

FROM thecodingmachine/php:8.5-v5-slim-apache

ENV PHP_INI_MAX_EXECUTION_TIME=240 \
    PHP_INI_MEMORY_LIMIT=512M \
    PHP_INI_POST_MAX_SIZE=128M \
    PHP_INI_UPLOAD_MAX_FILESIZE=128M

ARG IANSEO_URL="https://www.ianseo.net/Release/Ianseo_20250210.zip"
ARG IANSEO_CHECKSUM="a70a4acc1aebb1f9d01860e5e5dc15bcc949cf4488f1c44f72cc1a57d528f341"

RUN curl -fsSL ${IANSEO_URL} -o /tmp/ianseo.zip && \
    echo ${IANSEO_CHECKSUM} /tmp/ianseo.zip | sha256sum -c - && \
    unzip -q /tmp/ianseo.zip -d /var/www/html && \
    rm /tmp/ianseo.zip
