# Etapa 1: builder
FROM composer:2 AS builder
WORKDIR /app
COPY composer.json ./
RUN composer install --no-dev --no-interaction

# Etapa 2: runtime
FROM php:8.2-cli
RUN apt-get update && apt-get install -y libsqlite3-dev unzip git \
    && docker-php-ext-install pdo pdo_sqlite

RUN groupadd -g 1999 admingroup && useradd -m -u 1999 -g admingroup adminuser

WORKDIR /app
COPY --from=builder /app/vendor /app/vendor
COPY . /app

# Cria pasta do DB e garante permissão
RUN mkdir -p /app/data \
    && chown -R adminuser:admingroup /app/data

USER adminuser
EXPOSE 8080
CMD ["php", "-S", "0.0.0.0:8080", "src/index.php"]
