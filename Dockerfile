# Etapa 1: Builder - instala dependências usando Composer
FROM composer:2 AS builder
WORKDIR /app
COPY composer.json ./
# Instala dependências de produção sem pacotes de desenvolvimento
RUN composer install --no-dev --no-interaction

# Etapa 2: Runtime - imagem final de execução
FROM php:8.2-cli

# Instala dependências e extensões PHP
RUN apt-get update && apt-get install -y libsqlite3-dev unzip git \
    && docker-php-ext-install pdo pdo_sqlite

# Cria usuário não-root para execução da aplicação
RUN groupadd -g 1999 admingroup && useradd -m -u 1999 -g admingroup adminuser

WORKDIR /app

# Copia apenas a pasta vendor do builder
COPY --from=builder /app/vendor /app/vendor
# Copia o restante da aplicação
COPY . /app

# Cria pasta para o banco de dados SQLite e garante permissões para o usuário
RUN mkdir -p /app/data \
    && chown -R adminuser:admingroup /app/data

# Define que o container será executado como usuário não-root
USER adminuser

# Expõe a porta usada pelo servidor
EXPOSE 8080

# Inicia o servidor PHP
CMD ["php", "-S", "0.0.0.0:8080", "src/index.php"]
