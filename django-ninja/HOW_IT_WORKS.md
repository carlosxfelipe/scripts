# 🥷 Modern Setup: Django Ninja + UV + Python 3.14

This guide and automated script provide a complete, robust, and modern setup for building APIs using **Django**, **Django Ninja**, **Scalar**, and the ultra-fast package manager **UV**, powered by **Python 3.14** with **Ruff** for code quality.

---

## ⚡ Method 1: Automated Project Creation via Script

An interactive setup script is included in this folder:

```bash
chmod +x new-django-ninja.sh
./new-django-ninja.sh
```

The script will prompt you for the project name, Python version (defaults to `3.14`, with automatic fallback if an unrecognized version is entered), and whether to include Scalar, CORS, Django Ninja Extra, Ruff (linter/formatter), a modular sample app, migrations, and Git. In seconds, your project will be created, formatted, migrated, and ready to run.

---

## 🛠️ Method 2: Manual Step-by-Step Guide

If you prefer running the commands step-by-step in your terminal:

### 1. Initialize the project with UV and Python 3.14

```bash
uv init my_project --python 3.14
cd my_project
```

### 2. Install Django, API Dependencies, and Ruff

```bash
# Production dependencies
uv add django django-ninja scalar-ninja django-cors-headers

# Development tools (Linter & Formatter)
uv add --dev ruff
```

> **Optional (for larger projects requiring Class-Based Controllers & Dependency Injection):**
>
> ```bash
> uv add django-ninja-extra
> ```

### 3. Create the Django project structure

```bash
uv run django-admin startproject config .
```

### 4. Create the modular applications directory

```bash
mkdir -p apps
touch apps/__init__.py
```

### 5. Configure `config/settings.py`

Open `config/settings.py` and apply the following configurations:

#### a) Allow direct imports for apps inside `apps/`

Right after `BASE_DIR = Path(__file__).resolve().parent.parent`, add:

```python
import sys
# Allows importing apps inside the apps/ folder directly (e.g., import users instead of apps.users)
sys.path.insert(0, str(BASE_DIR / 'apps'))
```

#### b) Register CORS in `INSTALLED_APPS`

```python
INSTALLED_APPS = [
    # Third-party apps
    'corsheaders',

    # Django built-in apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Your apps (e.g., 'core', 'users', etc.)
]
```

#### c) Add CORS Middleware

Add `CorsMiddleware` at the very top of `MIDDLEWARE` (before `CommonMiddleware`):

```python
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    # ... remaining middlewares
]

# Allow all origins during local development
CORS_ALLOW_ALL_ORIGINS = True
ALLOWED_HOSTS = ['*']  # For local development
```

---

### 6. Configure Django Ninja with Scalar Docs (`config/api.py`)

Create `config/api.py`:

```python
from ninja import NinjaAPI
from scalar_ninja import ScalarConfig, ScalarViewer

api = NinjaAPI(
    title="Ninja API",
    version="1.0.0",
    description="High-performance API built with Django Ninja and documented with Scalar.",
    docs=ScalarViewer(ScalarConfig(layout="classic")),
)

# System health check endpoint
@api.get("/health", tags=["System"])
def health_check(request):
    return {
        "status": "healthy",
        "service": "django-ninja",
    }

# Example async endpoint
@api.get("/async-check", tags=["System"])
async def async_health_check(request):
    return {"message": "Native asynchronous support working seamlessly!"}
```

---

### 7. Connect the API in `config/urls.py`

Update `config/urls.py` to route `/api/` traffic to NinjaAPI:

```python
from django.contrib import admin
from django.urls import path
from config.api import api

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api.urls),  # All API endpoints routed under /api/
]
```

---

### 8. Format and Lint Code with Ruff

```bash
uv run ruff check --fix .
uv run ruff format .
```

---

### 9. Run Initial Migrations

```bash
uv run python manage.py migrate
```

---

### 10. Start the Development Server

```bash
uv run python manage.py runserver
```

### 11. Access the Endpoints

- 📖 **Interactive API Docs (Scalar):** [http://localhost:8000/api/docs](http://localhost:8000/api/docs)
- 🩺 **Health Check:** [http://localhost:8000/api/health](http://localhost:8000/api/health)
- 🏓 **Sample App Ping (if enabled):** [http://localhost:8000/api/core/ping](http://localhost:8000/api/core/ping)
- 🛠️ **Django Admin:** [http://localhost:8000/admin/](http://localhost:8000/admin/)

---

## 🧹 Code Quality with Ruff

Ruff is an extremely fast Python linter and code formatter created by Astral (the same team behind UV):

- **Format all files:**
  ```bash
  uv run ruff format .
  ```
- **Lint and auto-fix imports and issues:**
  ```bash
  uv run ruff check --fix .
  ```

---

## 🏗️ How to Create New Modular Apps

To keep your project structured into isolated modules inside `apps/`:

### 1. Create a new app inside `apps/`

```bash
uv run python manage.py startapp products apps/products
```

### 2. Register the app in `config/settings.py`

```python
INSTALLED_APPS = [
    ...
    'products',
]
```

### 3. Define the app routes in `apps/products/api.py`

```python
from ninja import Router, Schema

router = Router(tags=["Products"])

class ProductSchema(Schema):
    id: int
    name: str
    price: float

@router.get("/", response=list[ProductSchema])
def list_products(request):
    return [
        {"id": 1, "name": "Laptop", "price": 1299.99},
        {"id": 2, "name": "Wireless Mouse", "price": 49.99},
    ]
```

### 4. Register the Router in `config/api.py`

```python
from products.api import router as products_router

api.add_router("/products", products_router)
```

The endpoints will now be accessible at `/api/products/` and automatically documented in Scalar!
