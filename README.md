# docker-symfony-skeleton

Docker skeleton for bootstrapping a new Symfony 7 project. Relies on [local-network-multisite](https://github.com/rsida/local-network-multisite) for Traefik reverse proxy and local TLS certificate management.

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Docker + Docker Compose v2 | Docker 24+ |
| GNU Make | 4+ |
| local-network-multisite | running |

### local-network-multisite

This project **does not manage Traefik or TLS certificates**. Those are handled by `local-network-multisite`, which must be running before starting this project.

```bash
# In the local-network-multisite directory
make up
```

`local-network-multisite` creates the external network `traefik-net`. If that network is missing, containers will fail to start with:
```
network traefik-net declared as external, but could not be found
```

---

## Configuration

### 1. Copy the environment file

```bash
cp .env.example .env
```

### 2. Edit `.env`

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Unique project name (containers, network, Traefik router) | `symfony` |
| `APP_DOMAIN` | Local domain for the application | `symfony.local` |
| `APP_ENV` | Symfony environment | `dev` |
| `APP_SECRET` | Symfony secret key (change in production!) | `change-me-in-production` |
| `TRAEFIK_NETWORK` | External Traefik network (must match local-network-multisite) | `traefik-net` |
| `DB_ROOT_PASSWORD` | MariaDB root password | `root` |
| `DB_NAME` | Database name | `symfony` |
| `DB_USER` | MariaDB user | `symfony` |
| `DB_PASSWORD` | MariaDB user password | `symfony` |

> **Important**: `APP_NAME` must be **unique** across all local-network-multisite projects on your machine. It is used as a prefix for container names and Traefik routers.

---

## First launch — Step by step

### Scenario 1 — Create a brand new Symfony project

Use this **once** to bootstrap a fresh Symfony application.

#### 1. Clone the skeleton

```bash
git clone <this-repo-url> my-project
cd my-project
```

#### 2. Configure the environment

```bash
cp .env.example .env
# Edit .env: set APP_NAME, APP_DOMAIN, DB passwords, APP_SECRET
```

#### 3. Add the domain to `/etc/hosts`

```bash
echo "127.0.0.1 my-project.local mail.my-project.local" | sudo tee -a /etc/hosts
```

Replace `my-project.local` with the value of `APP_DOMAIN` from your `.env`.

On **Windows (WSL2)**, also add the same line to `C:\Windows\System32\drivers\etc\hosts`.

#### 4. Run the installation

```bash
make install
```

This command runs in order:
1. Creates `.env` from `.env.example` if missing
2. Builds the PHP Docker image
3. Starts all containers (nginx, php, mariadb, mailpit)
4. Waits for MariaDB to be ready
5. Creates a new Symfony project via `composer create-project symfony/skeleton`
6. Installs the `webapp` pack (Twig, Doctrine, Security, Mailer, AssetMapper…)
7. Writes `.env.local` with database and mailer configuration
8. Creates the database and runs migrations
9. Warms up the Symfony cache

When complete:
```
Symfony is ready!
  App:     https://my-project.local
  Mail:    https://mail.my-project.local
```

#### 5. Commit the Symfony application

After `make install`, the Symfony files are in the directory. Commit them so other developers can use `make setup` instead of `make install`:

```bash
git add composer.json composer.lock config/ src/ templates/ migrations/ public/ assets/ importmap.php
git commit -m "chore: initial Symfony installation"
git push
```

---

### Scenario 2 — Join an existing project

Use this when `make install` has already been run and `composer.json` is present in the repository.

#### 1. Clone the project

```bash
git clone <project-repo-url> my-project
cd my-project
```

#### 2. Configure the environment

```bash
cp .env.example .env
# Fill in the credentials provided by your team (DB_PASSWORD, APP_SECRET, etc.)
```

#### 3. Add the domain to `/etc/hosts`

```bash
echo "127.0.0.1 my-project.local mail.my-project.local" | sudo tee -a /etc/hosts
```

#### 4. Run setup

```bash
make setup
```

`make setup` installs Composer dependencies, creates the database, and runs migrations **without** re-running `composer create-project`.

---

## Available Makefile commands

| Command | Description |
|---------|-------------|
| `make install` | First-time full setup: creates Symfony project, builds images, starts containers, runs migrations |
| `make setup` | Setup for subsequent developers: installs deps, runs migrations (no create-project) |
| `make up` | Start all containers in detached mode |
| `make down` | Stop and remove containers (volumes are preserved) |
| `make build` | (Re)build Docker images |
| `make restart` | Restart all containers |
| `make logs` | Follow logs for all services |
| `make logs SERVICES="php nginx"` | Follow logs for specific services |
| `make ps` | Show running container status |
| `make shell` | Open a bash shell in the PHP container |
| `make composer CMD="require package/name"` | Run a Composer command |
| `make console CMD="cache:clear"` | Run a Symfony console command |
| `make cache-clear` | Clear Symfony cache |
| `make db-create` | Create the database |
| `make db-migrate` | Run database migrations |
| `make db-fixtures` | Load data fixtures |
| `make easyadmin-install` | Install EasyAdminBundle and generate a basic DashboardController |
| `make easyadmin-crud ENTITY=Product` | Generate an EasyAdmin CRUD controller for an entity |
| `make test` | Run PHPUnit test suite |
| `make fix-perms` | Fix permissions on the `var/` directory |

---

## EasyAdmin setup guide

### Step 1 — Install EasyAdmin

```bash
make easyadmin-install
```

This command:
1. Installs `easycorp/easyadmin-bundle` via Composer
2. Generates a `DashboardController` at `src/Controller/Admin/DashboardController.php`

### Step 2 — Access the dashboard

Navigate to `https://<APP_DOMAIN>/admin`.

By default the admin panel is **not protected**. You should configure Symfony Security before going to production.

### Step 3 — Generate CRUD controllers

For each entity you want to manage:

```bash
make easyadmin-crud ENTITY=Product
make easyadmin-crud ENTITY=Category
```

### Step 4 — Configure the dashboard menu

Open `src/Controller/Admin/DashboardController.php` and update the `configureMenuItems()` method:

```php
public function configureMenuItems(): iterable
{
    yield MenuItem::linkToDashboard('Dashboard', 'fa fa-home');
    yield MenuItem::linkToCrud('Products', 'fa fa-tag', Product::class);
    yield MenuItem::linkToCrud('Categories', 'fa fa-list', Category::class);
}
```

### Step 5 — Protect the admin (recommended)

Install Symfony Security and restrict the `/admin` route:

```bash
make composer CMD="require symfony/security-bundle"
make console CMD="make:user"
make console CMD="make:auth"
```

Then in `config/packages/security.yaml`, add an access control:

```yaml
access_control:
    - { path: ^/admin, roles: ROLE_ADMIN }
```

---

## Useful URLs

| URL | Description |
|-----|-------------|
| `https://<APP_DOMAIN>` | Symfony application |
| `https://<APP_DOMAIN>/admin` | EasyAdmin back-office (after `make easyadmin-install`) |
| `https://mail.<APP_DOMAIN>` | Mailpit email catcher |

---

## Xdebug

Xdebug is installed and configured for PHPStorm. It runs in **trigger mode**: it only activates on demand and has no performance impact during normal browsing.

**To enable debugging:**

1. Install the [Xdebug Helper](https://chromewebstore.google.com/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc) browser extension
2. Enable "Debug" mode in the extension (green icon)
3. In PHPStorm, start "Listen for PHP Debug Connections" (phone icon)
4. Set a breakpoint and reload the page

Xdebug settings:
- Port: `9003`
- IDE Key: `PHPSTORM`

---

## Services

| Service | Internal address | Description |
|---------|-----------------|-------------|
| Application | `https://<APP_DOMAIN>` | Symfony frontend |
| Mailpit | `https://mail.<APP_DOMAIN>` | Email catcher (dev) |
| MariaDB | `mariadb:3306` (internal only) | Database |

Ports are **not** exposed on the host — all traffic goes through Traefik (managed by local-network-multisite).

---

## Project structure

```
docker-symfony-skeleton/
├── docker/
│   ├── nginx/
│   │   └── default.conf        # Nginx config (PHP-FPM + Traefik HTTPS forwarding)
│   └── php/
│       ├── Dockerfile           # PHP 8.3-FPM + Symfony extensions + Composer 2
│       ├── php.ini              # PHP settings (memory 512M, upload 64M)
│       └── xdebug.ini           # Xdebug 3 config (trigger mode, port 9003)
├── .dockerignore
├── .env.example                 # Configuration template — copy to .env
├── .gitignore
├── compose.yaml                 # Services: nginx, php, mariadb, mailpit
├── Makefile                     # Development commands
└── README.md
```

After `make install`, the Symfony application files are added at the root of this directory alongside the Docker configuration.

---

## Troubleshooting

### `network traefik-net declared as external, but could not be found`

local-network-multisite is not running. Start it first:

```bash
cd ~/project/local-network-multisite && make up
```

### `502 Bad Gateway`

The PHP container is not ready yet, or crashed. Check the logs:

```bash
make logs SERVICES="php"
```

### `Database connection refused`

MariaDB may still be initializing. Wait a few seconds and retry. You can also check:

```bash
make logs SERVICES="mariadb"
```

### Permission errors on `var/`

```bash
make fix-perms
```

### Composer `out of memory` error

Increase PHP memory limit in `docker/php/php.ini` (`memory_limit`) and rebuild:

```bash
make build
make up
```

### `.env.local` is missing

After cloning an existing project, copy and fill the credentials:

```bash
cp .env.example .env
# Set DB_PASSWORD, APP_SECRET, etc.
make setup
```
