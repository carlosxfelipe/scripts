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

USE_EXTRA=N
ask_yn "Include django-ninja-extra (Class-based controllers, DI, permissions)?" "N" && USE_EXTRA=Y

USE_RUFF=N
ask_yn "Install Ruff (fast linter and code formatter by Astral) as dev dependency?" "Y" && USE_RUFF=Y

CREATE_SAMPLE_APP=N
ask_yn "Scaffold a sample modular app in 'apps/core' with Ninja Router?" "Y" && CREATE_SAMPLE_APP=Y

RUN_MIGRATIONS=N
ask_yn "Run initial database migrations?" "Y" && RUN_MIGRATIONS=Y

INIT_GIT=N
ask_yn "Initialize git repository and initial commit?" "Y" && INIT_GIT=Y

echo
echo "=========================================="
echo "Project:     $NAME"
echo "Directory:   $DIR"
echo "Python:      $PYTHON_VERSION"
echo "Scalar Docs: $USE_SCALAR"
echo "CORS:        $USE_CORS"
echo "Ninja Extra: $USE_EXTRA"
echo "Ruff:        $USE_RUFF"
echo "Sample App:  $CREATE_SAMPLE_APP"
echo "Migrations:  $RUN_MIGRATIONS"
echo "Git Init:    $INIT_GIT"
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
[[ "$USE_EXTRA" == "Y" ]] && DEPS+=("django-ninja-extra")

uv add "${DEPS[@]}"

if [[ "$USE_RUFF" == "Y" ]]; then
  echo "🧹 2.1 Installing Ruff dev dependency..."
  uv add --dev ruff
fi

echo "🏗️  3. Creating Django project structure..."
uv run django-admin startproject config .

mkdir -p apps
touch apps/__init__.py

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
use_core = '$CREATE_SAMPLE_APP' == 'Y'

for line in lines:
    if line.startswith('ALLOWED_HOSTS = '):
        new_lines.append(\"ALLOWED_HOSTS = ['*']\")
        continue
    new_lines.append(line)
    if 'BASE_DIR = ' in line:
        new_lines.append('')
        new_lines.append('# Add apps directory to Python path for clean modular imports')
        new_lines.append('import sys')
        new_lines.append('sys.path.insert(0, str(BASE_DIR / \"apps\"))')
    elif 'INSTALLED_APPS = [' in line:
        if use_cors:
            new_lines.append('    \"corsheaders\",')
        if use_core:
            new_lines.append('    \"core\",')
    elif 'MIDDLEWARE = [' in line:
        if use_cors:
            new_lines.append('    \"corsheaders.middleware.CorsMiddleware\",')

result = '\n'.join(new_lines) + '\n'

if use_cors:
    result += '''
# CORS Configuration (Development)
CORS_ALLOW_ALL_ORIGINS = True
'''

settings_file.write_text(result, encoding='utf-8')
"

echo "🔌 6. Scaffolding config/api.py..."
if [[ "$USE_SCALAR" == "Y" ]]; then
  cat <<'EOF' >config/api.py
from ninja import NinjaAPI
from scalar_ninja import ScalarViewer

api = NinjaAPI(
    title="Ninja API",
    version="1.0.0",
    description="API documentation powered by Scalar and Django Ninja",
    docs=ScalarViewer(),
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
  git commit -q -m "Initial commit: Django Ninja project created with UV (Python $PYTHON_VERSION)"
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
[[ "$CREATE_SAMPLE_APP" == "Y" ]] && echo "   🏓 Core Ping:    http://localhost:8000/api/core/ping"
echo "   🛠️  Admin:       http://localhost:8000/admin/"
echo
if [[ "$USE_RUFF" == "Y" ]]; then
  echo "🧹 Code Quality (Ruff):"
  echo "   uv run ruff format .     # Format all code"
  echo "   uv run ruff check --fix  # Lint and auto-fix"
  echo
fi
echo "💡 To create another app inside 'apps/':"
echo "   uv run python manage.py startapp meu_app apps/meu_app"
echo "   (1. Add 'meu_app' to INSTALLED_APPS in config/settings.py)"
echo "   (2. Create apps/meu_app/api.py with a router)"
echo "   (3. Register it in config/api.py: api.add_router('/meu-app', router))"
echo
