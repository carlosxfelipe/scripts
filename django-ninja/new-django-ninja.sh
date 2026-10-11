#!/usr/bin/env bash
# Creates a modern Django + Django Ninja API project with UV and Python 3.14.
# Usage: ./new-django-ninja.sh   (Enter accepts the default value in brackets)

set -euo pipefail

ask() { # ask "question" "default" -> echoes reply
  local reply
  read -r -p "$1 [$2]: " reply
  echo "${reply:-$2}"
}

ask_yn() { # ask_yn "question" "Y|N"
  local r
  r=$(ask "$1 (y/n)" "$2")
  case "$(echo "$r" | tr '[:upper:]' '[:lower:]')" in y | yes) return 0 ;; *) return 1 ;; esac
}

command -v uv >/dev/null || {
  echo "❌ Error: 'uv' package manager was not found."
  echo "Install it via: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
}

echo "=== 🥷 New Django Ninja API Project Setup ==="
NAME=$(ask "Project name" "my_ninja_api")
NAME=$(echo "$NAME" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
DIR=$(ask "Target directory" "$PWD/$NAME")
DEFAULT_PYTHON="3.14"
PYTHON_VERSION=$(ask "Python version" "$DEFAULT_PYTHON")

if [[ "$PYTHON_VERSION" != "$DEFAULT_PYTHON" ]]; then
  if [[ -z "$(uv python list "$PYTHON_VERSION" 2>/dev/null)" ]]; then
    echo "⚠️  Python version '$PYTHON_VERSION' was not found by UV. Falling back to default: $DEFAULT_PYTHON"
    PYTHON_VERSION="$DEFAULT_PYTHON"
  fi
fi

USE_SCALAR=N
ask_yn "Use Scalar for interactive API docs (modern Swagger alternative)?" "Y" && USE_SCALAR=Y

USE_CORS=N
ask_yn "Configure django-cors-headers (recommended for Web/Mobile APIs)?" "Y" && USE_CORS=Y

USE_JWT=N
ask_yn "Configure JWT authentication (django-ninja-jwt + email-validator)?" "Y" && USE_JWT=Y

USE_EXTRA=N
if [[ "$USE_JWT" == "Y" ]]; then
  USE_EXTRA=Y
else
  ask_yn "Include django-ninja-extra (Class-based controllers, DI, permissions)?" "N" && USE_EXTRA=Y
fi

USE_RUFF=N
ask_yn "Install Ruff (fast linter and code formatter by Astral) as dev dependency?" "Y" && USE_RUFF=Y

USE_DJANGO_STUBS=N
ask_yn "Install django-stubs (typing and editor autocomplete) as dev dependency?" "Y" && USE_DJANGO_STUBS=Y

CREATE_SAMPLE_APP=N
ask_yn "Scaffold a sample modular app in 'apps/core' with Ninja Router?" "Y" && CREATE_SAMPLE_APP=Y

USE_BRAZIL_LOCALE=N
ask_yn "Configure Brazilian Portuguese locale & timezone (pt-br / America/Fortaleza)?" "Y" && USE_BRAZIL_LOCALE=Y

RUN_MIGRATIONS=N
ask_yn "Run initial database migrations?" "Y" && RUN_MIGRATIONS=Y

INIT_GIT=N
ask_yn "Initialize git repository and initial commit?" "Y" && INIT_GIT=Y

echo
echo "=========================================="
echo "Project:        $NAME"
echo "Directory:      $DIR"
echo "Python:         $PYTHON_VERSION"
echo "Scalar Docs:    $USE_SCALAR"
echo "CORS:           $USE_CORS"
echo "JWT Auth:       $USE_JWT"
echo "Ninja Extra:    $USE_EXTRA"
echo "Ruff:           $USE_RUFF"
echo "Django Stubs:   $USE_DJANGO_STUBS"
echo "Sample App:     $CREATE_SAMPLE_APP"
echo "Brazil Locale:  $USE_BRAZIL_LOCALE"
echo "Migrations:     $RUN_MIGRATIONS"
echo "Git Init:       $INIT_GIT"
echo "=========================================="
ask_yn "Confirm project creation?" "Y" || {
  echo "Cancelled."
  exit 0
}

mkdir -p "$DIR"
cd "$DIR"

echo
echo "🚀 1. Initializing UV project with Python $PYTHON_VERSION..."
uv init . --python "$PYTHON_VERSION" --name "$NAME" >/dev/null

echo "📦 2. Installing dependencies..."
DEPS=("django" "django-ninja")
[[ "$USE_SCALAR" == "Y" ]] && DEPS+=("scalar-ninja")
[[ "$USE_CORS" == "Y" ]] && DEPS+=("django-cors-headers")
[[ "$USE_EXTRA" == "Y" && "$USE_JWT" != "Y" ]] && DEPS+=("django-ninja-extra")
if [[ "$USE_JWT" == "Y" ]]; then
  DEPS+=("django-ninja-jwt" "email-validator")
fi

uv add "${DEPS[@]}"

DEV_DEPS=()
[[ "$USE_RUFF" == "Y" ]] && DEV_DEPS+=("ruff")
[[ "$USE_DJANGO_STUBS" == "Y" ]] && DEV_DEPS+=("django-stubs")

if [[ ${#DEV_DEPS[@]} -gt 0 ]]; then
  echo "🛠️  2.1 Installing dev dependencies (${DEV_DEPS[*]})..."
  uv add --dev "${DEV_DEPS[@]}"
fi

echo "🏗️  3. Creating Django project structure..."
uv run django-admin startproject config .

mkdir -p apps
touch apps/__init__.py

# Configure static analysis search paths for editors/IDEs (Pyright, Pyrefly, ty)
cat <<'EOF' >>pyproject.toml

# The editor's static analysis doesn't run settings.py, so it can't see
# sys.path.insert(0, BASE_DIR / "apps"). Tell it where apps live.
[tool.pyrefly]
search-path = ["apps"]

[tool.pyright]
extraPaths = ["apps"]

[tool.ty.environment]
extra-paths = ["apps"]
EOF

if [[ "$CREATE_SAMPLE_APP" == "Y" ]]; then
  echo "🧩 4. Scaffolding sample modular app 'core' in apps/..."
  mkdir -p apps/core
  uv run python manage.py startapp core apps/core

  cat <<'EOF' >apps/core/api.py
from ninja import Router

router = Router(tags=["Core"])

@router.get("/ping")
def ping(request):
    """Sample ping endpoint from modular router."""
    return {"message": "pong from apps/core"}
EOF
fi

echo "⚙️  5. Configuring settings.py and sys.path..."
uv run python -c "
from pathlib import Path

settings_file = Path('config/settings.py')
content = settings_file.read_text(encoding='utf-8')
lines = content.splitlines()
new_lines = []

use_cors = '$USE_CORS' == 'Y'
use_jwt = '$USE_JWT' == 'Y'
use_extra = '$USE_EXTRA' == 'Y' or use_jwt
use_core = '$CREATE_SAMPLE_APP' == 'Y'
use_brazil_locale = '$USE_BRAZIL_LOCALE' == 'Y'

has_timedelta_import = False

for line in lines:
    if line.startswith('ALLOWED_HOSTS = '):
        new_lines.append(\"ALLOWED_HOSTS = ['*']\")
        continue
    if use_brazil_locale:
        if line.startswith('LANGUAGE_CODE ='):
            new_lines.append(\"LANGUAGE_CODE = 'pt-br'\")
            continue
        if line.startswith('TIME_ZONE ='):
            new_lines.append(\"TIME_ZONE = 'America/Fortaleza'\")
            continue
        if line.startswith('USE_I18N ='):
            new_lines.append('USE_I18N = True')
            continue
        if line.startswith('USE_TZ ='):
            new_lines.append('USE_TZ = True')
            continue
    new_lines.append(line)
    if 'from pathlib import Path' in line and use_jwt:
        new_lines.append('from datetime import timedelta')
        has_timedelta_import = True
    elif 'BASE_DIR = ' in line:
        new_lines.append('')
        new_lines.append('# Add apps directory to Python path for clean modular imports')
        new_lines.append('import sys')
        new_lines.append('sys.path.insert(0, str(BASE_DIR / \"apps\"))')
    elif 'INSTALLED_APPS = [' in line:
        if use_cors:
            new_lines.append('    \"corsheaders\",')
        if use_jwt:
            new_lines.append('    \"ninja_extra\",')
            new_lines.append('    \"ninja_jwt\",')
            new_lines.append('    \"ninja_jwt.token_blacklist\",')
        elif use_extra:
            new_lines.append('    \"ninja_extra\",')
        if use_core:
            new_lines.append('    \"core\",')
    elif 'MIDDLEWARE = [' in line:
        if use_cors:
            new_lines.append('    \"corsheaders.middleware.CorsMiddleware\",')

if use_jwt and not has_timedelta_import:
    new_lines.insert(0, 'from datetime import timedelta')

result = '\n'.join(new_lines) + '\n'

if use_cors:
    result += '''
# CORS Configuration (Development)
CORS_ALLOW_ALL_ORIGINS = True
'''

if use_jwt:
    result += '''
# JWT Configuration (django-ninja-jwt)
NINJA_JWT = {
    \"ACCESS_TOKEN_LIFETIME\": timedelta(minutes=30),
    \"REFRESH_TOKEN_LIFETIME\": timedelta(days=7),
    \"ROTATE_REFRESH_TOKENS\": True,
    \"BLACKLIST_AFTER_ROTATION\": True,
}
'''

settings_file.write_text(result, encoding='utf-8')
"

echo "🔌 6. Scaffolding config/api.py..."
if [[ "$USE_JWT" == "Y" ]]; then
  if [[ "$USE_SCALAR" == "Y" ]]; then
    cat <<'EOF' >config/api.py
from ninja_extra import ControllerBase, NinjaExtraAPI, api_controller
from ninja_extra.permissions import AllowAny
from ninja_jwt.controller import (
    NinjaJWTDefaultController,
    TokenBlackListController,
)
from scalar_ninja import ScalarConfig, ScalarViewer


@api_controller("/token", permissions=[AllowAny], tags=["Token"], auth=None)
class NinjaJWTExtendedController(
    NinjaJWTDefaultController, TokenBlackListController, ControllerBase
):
    """Full JWT endpoints: pair, refresh, verify, and blacklist (logout)."""

    auto_import = False


api = NinjaExtraAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Scalar and Django Ninja",
    docs=ScalarViewer(ScalarConfig(layout="classic")),
)

# JWT endpoints: /api/token/pair, /api/token/refresh, /api/token/verify, /api/token/blacklist
api.register_controllers(NinjaJWTExtendedController)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  else
    cat <<'EOF' >config/api.py
from ninja_extra import ControllerBase, NinjaExtraAPI, api_controller
from ninja_extra.permissions import AllowAny
from ninja_jwt.controller import (
    NinjaJWTDefaultController,
    TokenBlackListController,
)


@api_controller("/token", permissions=[AllowAny], tags=["Token"], auth=None)
class NinjaJWTExtendedController(
    NinjaJWTDefaultController, TokenBlackListController, ControllerBase
):
    """Full JWT endpoints: pair, refresh, verify, and blacklist (logout)."""

    auto_import = False


api = NinjaExtraAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Django Ninja",
)

# JWT endpoints: /api/token/pair, /api/token/refresh, /api/token/verify, /api/token/blacklist
api.register_controllers(NinjaJWTExtendedController)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  fi
elif [[ "$USE_EXTRA" == "Y" ]]; then
  if [[ "$USE_SCALAR" == "Y" ]]; then
    cat <<'EOF' >config/api.py
from ninja_extra import NinjaExtraAPI
from scalar_ninja import ScalarConfig, ScalarViewer

api = NinjaExtraAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Scalar and Django Ninja Extra",
    docs=ScalarViewer(ScalarConfig(layout="classic")),
)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  else
    cat <<'EOF' >config/api.py
from ninja_extra import NinjaExtraAPI

api = NinjaExtraAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Django Ninja Extra",
)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  fi
else
  if [[ "$USE_SCALAR" == "Y" ]]; then
    cat <<'EOF' >config/api.py
from ninja import NinjaAPI
from scalar_ninja import ScalarConfig, ScalarViewer

api = NinjaAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Scalar and Django Ninja",
    docs=ScalarViewer(ScalarConfig(layout="classic")),
)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  else
    cat <<'EOF' >config/api.py
from ninja import NinjaAPI

api = NinjaAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Django Ninja",
)


@api.get("/health", tags=["System"])
def health_check(request):
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "django-ninja",
    }
EOF
  fi
fi

if [[ "$CREATE_SAMPLE_APP" == "Y" ]]; then
  cat <<'EOF' >>config/api.py

# Register modular routers
from core.api import router as core_router
api.add_router("/core", core_router)
EOF
fi

echo "🗺️  7. Wiring API into config/urls.py..."
cat <<'EOF' >config/urls.py
from django.contrib import admin
from django.urls import path
from config.api import api

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api.urls),
]
EOF

echo "📝 8. Creating .gitignore and .env.example..."
cat <<'EOF' >.gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
.venv/
env/
venv/
ENV/
build/
dist/
*.egg-info/

# Ruff
.ruff_cache/

# Django
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal
media/
staticfiles/

# Environment
.env
.env.local

# IDE & OS
.vscode/
.idea/
.DS_Store
Thumbs.db
EOF

cat <<'EOF' >.env.example
DEBUG=True
SECRET_KEY=django-insecure-change-this-in-production
ALLOWED_HOSTS=*
EOF

if [[ "$USE_RUFF" == "Y" ]]; then
  echo "✨ 9. Formatting and linting codebase with Ruff..."
  uv run ruff check --fix . >/dev/null 2>&1 || true
  uv run ruff format . >/dev/null 2>&1 || true
fi

if [[ "$RUN_MIGRATIONS" == "Y" ]]; then
  echo "🗄️  10. Running initial database migrations..."
  uv run python manage.py migrate
fi

if [[ "$INIT_GIT" == "Y" ]]; then
  echo "🌱 11. Initializing Git repository..."
  git init -q
  git add .
  git commit -q -m "Initial commit"
fi

echo
echo "============================================================"
echo "🎉 Project '$NAME' created successfully at:"
echo "   $DIR"
echo "============================================================"
echo
echo "🚀 Quick start:"
echo "   cd \"$DIR\""
echo "   uv run python manage.py runserver"
echo
echo "🌐 Available Endpoints:"
echo "   📖 API Docs:    http://localhost:8000/api/docs"
echo "   🩺 Health Check: http://localhost:8000/api/health"
[[ "$USE_JWT" == "Y" ]] && echo "   🔑 JWT Token:    http://localhost:8000/api/token/pair"
[[ "$CREATE_SAMPLE_APP" == "Y" ]] && echo "   🏓 Core Ping:    http://localhost:8000/api/core/ping"
echo "   🛠️  Admin:       http://localhost:8000/admin/"
echo
if [[ "$USE_RUFF" == "Y" ]]; then
  echo "🧹 Code Quality (Ruff):"
  echo "   uv run ruff format .     # Format all code"
  echo "   uv run ruff check --fix  # Lint and auto-fix"
  echo
fi
if [[ "$USE_DJANGO_STUBS" == "Y" ]]; then
  echo "🛡️  Type Safety & Autocomplete (django-stubs):"
  echo "   Configured in dev dependencies and IDE path settings (Pyright/Pyrefly)."
  echo
fi
echo "💡 To create another app inside 'apps/':"
echo "   uv run python manage.py startapp my_app apps/my_app"
echo "   (1. Add 'my_app' to INSTALLED_APPS in config/settings.py)"
echo "   (2. Create apps/my_app/api.py with a router)"
echo "   (3. Register it in config/api.py: api.add_router('/my-app', router))"
echo
