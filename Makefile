# docker-symfony-skeleton Makefile
#
# First-time setup:
#   cp .env.example .env   # edit APP_NAME, APP_DOMAIN, passwords
#   make install           # build images, start containers, create Symfony project
#
# Daily usage:
#   make up    / make down
#   make shell             # PHP container bash
#   make console CMD="cache:clear"
#   make logs

ifneq (,$(wildcard .env))
  include .env
  export
endif

APP_NAME    ?= symfony
APP_DOMAIN  ?= symfony.local
COMPOSE     := docker compose
PHP         := $(COMPOSE) exec php

.PHONY: install setup up down build restart shell composer console \
        cache-clear logs ps \
        db-create db-migrate db-fixtures \
        easyadmin-install easyadmin-crud \
        test fix-perms \
        symfony-init \
        help

## ─── Help ────────────────────────────────────────────────────────────────────

## help: List available targets
help:
	@grep -E '^## ' Makefile | sed 's/^## //' | column -t -s ':'

## ─── Setup ───────────────────────────────────────────────────────────────────

## install: First-time full setup — creates Symfony project, builds images, starts containers
install: _env build up _wait-db _symfony-init
	@echo ""
	@echo "Symfony is ready!"
	@echo "  App:     https://$(APP_DOMAIN)"
	@echo "  Admin:   https://$(APP_DOMAIN)/admin  (after easyadmin-install)"
	@echo "  Mail:    https://mail.$(APP_DOMAIN)"
	@echo ""
	@echo "Make sure /etc/hosts contains: 127.0.0.1 $(APP_DOMAIN) mail.$(APP_DOMAIN)"

## setup: Setup for subsequent developers — installs deps and runs migrations (no create-project)
setup: _env build up _wait-db _symfony-setup
	@echo ""
	@echo "Setup complete!"
	@echo "  App:     https://$(APP_DOMAIN)"
	@echo "  Mail:    https://mail.$(APP_DOMAIN)"
	@echo ""
	@echo "Make sure /etc/hosts contains: 127.0.0.1 $(APP_DOMAIN) mail.$(APP_DOMAIN)"

## ─── Containers ──────────────────────────────────────────────────────────────

## up: Start all containers in detached mode
up:
	$(COMPOSE) up -d

## down: Stop and remove containers (volumes are preserved)
down:
	$(COMPOSE) down

## build: Build Docker images
build:
	$(COMPOSE) build

## restart: Restart all containers
restart: down up

## logs: Follow logs for all services (or SERVICES="php nginx" make logs)
logs:
	$(COMPOSE) logs -f $(SERVICES)

## ps: Show running services
ps:
	$(COMPOSE) ps

## ─── Application ─────────────────────────────────────────────────────────────

## shell: Open a bash shell in the PHP container
shell:
	$(PHP) bash

## composer: Run a Composer command — usage: make composer CMD="require package/name"
composer:
	$(PHP) composer $(CMD)

## console: Run a Symfony console command — usage: make console CMD="cache:clear"
console:
	$(PHP) php bin/console $(CMD)

## cache-clear: Clear Symfony cache
cache-clear:
	$(PHP) php bin/console cache:clear

## ─── Database ────────────────────────────────────────────────────────────────

## db-create: Create the database
db-create:
	$(PHP) php bin/console doctrine:database:create --if-not-exists

## db-migrate: Run database migrations
db-migrate:
	$(PHP) php bin/console doctrine:migrations:migrate --no-interaction

## db-fixtures: Load data fixtures
db-fixtures:
	$(PHP) php bin/console doctrine:fixtures:load --no-interaction

## ─── EasyAdmin ───────────────────────────────────────────────────────────────

## easyadmin-install: Install EasyAdminBundle and generate a basic DashboardController
easyadmin-install:
	@echo ">>> Installing EasyAdminBundle..."
	$(PHP) composer require easycorp/easyadmin-bundle
	@echo ">>> Generating DashboardController..."
	$(PHP) php bin/console make:admin:dashboard --no-interaction
	@echo ""
	@echo "EasyAdmin installed!"
	@echo "  Dashboard: https://$(APP_DOMAIN)/admin"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Open src/Controller/Admin/DashboardController.php and configure your menu"
	@echo "  2. Run: make easyadmin-crud ENTITY=YourEntity"

## easyadmin-crud: Generate an EasyAdmin CRUD controller — usage: make easyadmin-crud ENTITY=Product
easyadmin-crud:
	@if [ -z "$(ENTITY)" ]; then \
		echo "ERROR: ENTITY is required. Usage: make easyadmin-crud ENTITY=Product"; \
		exit 1; \
	fi
	$(PHP) php bin/console make:admin:crud --entity="App\\Entity\\$(ENTITY)" --no-interaction

## ─── Tests ───────────────────────────────────────────────────────────────────

## test: Run PHPUnit test suite
test:
	$(PHP) php bin/phpunit

## ─── Utilities ───────────────────────────────────────────────────────────────

## fix-perms: Fix permissions on var/ directory
fix-perms:
	$(COMPOSE) exec -u root php chown -R www-data:www-data /var/www/html/var
	$(COMPOSE) exec -u root php chmod -R 775 /var/www/html/var

# ─── Internal targets ────────────────────────────────────────────────────────

_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env created from .env.example — review it before continuing."; \
	fi

_wait-db:
	@echo ">>> Waiting for MariaDB to be ready..."
	@$(COMPOSE) exec mariadb bash -c \
		'until mariadb-admin ping -u root -p"$$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do sleep 1; done'
	@echo ">>> MariaDB is ready."

_symfony-init:
	@echo ">>> Checking if Symfony application already exists..."
	@if [ -f composer.json ]; then \
		echo ">>> composer.json found — skipping create-project, running composer install..."; \
		$(PHP) composer install --no-interaction; \
	else \
		echo ">>> Creating Symfony project (symfony/skeleton + webapp)..."; \
		$(PHP) composer create-project symfony/skeleton /tmp/symfony-install --no-interaction --prefer-dist; \
		$(PHP) bash -c 'cp -rn /tmp/symfony-install/. /var/www/html/ && rm -rf /tmp/symfony-install'; \
		$(PHP) bash -c 'rm -f /var/www/html/compose.yaml /var/www/html/docker-compose.yml /var/www/html/docker-compose.yaml'; \
		echo ">>> Installing webapp pack (Twig, Doctrine, Security, Mailer...)..."; \
		$(PHP) composer require webapp --no-interaction; \
	fi
	@echo ">>> Writing .env.local..."
	@$(PHP) bash -c 'cat > /var/www/html/.env.local <<EOF\nAPP_ENV=dev\nAPP_SECRET=$$APP_SECRET\nDATABASE_URL=mysql://$$DB_USER:$$DB_PASSWORD@mariadb:3306/$$DB_NAME?serverVersion=mariadb-11.0.0&charset=utf8mb4\nMAILER_DSN=smtp://mailer:1025\nEOF'
	@echo ">>> Running database migrations..."
	$(PHP) php bin/console doctrine:database:create --if-not-exists
	$(PHP) php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
	@echo ">>> Warming up cache..."
	$(PHP) php bin/console cache:warmup
	$(COMPOSE) exec -u root php chown -R www-data:www-data /var/www/html/var

_symfony-setup:
	@echo ">>> Installing Composer dependencies..."
	$(PHP) composer install --no-interaction
	@if [ ! -f .env.local ]; then \
		echo ">>> Writing .env.local..."; \
		$(PHP) bash -c 'cat > /var/www/html/.env.local <<EOF\nAPP_ENV=dev\nAPP_SECRET=$$APP_SECRET\nDATABASE_URL=mysql://$$DB_USER:$$DB_PASSWORD@mariadb:3306/$$DB_NAME?serverVersion=mariadb-11.0.0&charset=utf8mb4\nMAILER_DSN=smtp://mailer:1025\nEOF'; \
	fi
	@echo ">>> Running database migrations..."
	$(PHP) php bin/console doctrine:database:create --if-not-exists
	$(PHP) php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
	@echo ">>> Warming up cache..."
	$(PHP) php bin/console cache:warmup
	$(COMPOSE) exec -u root php chown -R www-data:www-data /var/www/html/var
