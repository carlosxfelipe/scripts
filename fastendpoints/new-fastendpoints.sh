#!/usr/bin/env bash
# Creates a FastEndpoints API project with Scalar and TUnit.
# Usage: ./new-fastendpoints.sh

set -euo pipefail

ask() {
  local reply
  read -r -p "$1 [$2]: " reply
  echo "${reply:-$2}"
}

ask_yn() {
  local r
  r=$(ask "$1 (y/n)" "$2")

  case "$(echo "$r" | tr '[:upper:]' '[:lower:]')" in
  y | yes) return 0 ;;
  *) return 1 ;;
  esac
}

command -v dotnet >/dev/null || {
  echo "dotnet SDK not found."
  exit 1
}

# Install TUnit templates if needed
if ! dotnet new list TUnit 2>/dev/null | grep -q TUnit; then
  echo "Installing TUnit templates..."
  dotnet new install TUnit.Templates
fi

echo "=== New FastEndpoints Project ==="

while true; do
  NAME=$(ask "Project name" "MyApi")
  NAME=${NAME// /}

  if [[ ! "$NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*$ ]]; then
    echo "❌ Invalid project name: '$NAME'. Must be a valid C# identifier (only letters, numbers, underscores, and cannot start with a number)."
    continue
  fi

  case "$NAME" in
  abstract | as | base | bool | break | byte | case | catch | char | checked | class | const | continue | decimal | default | delegate | do | double | else | enum | event | explicit | extern | false | finally | fixed | float | for | foreach | goto | if | implicit | in | int | interface | internal | is | lock | long | namespace | new | null | object | operator | out | override | params | private | protected | public | readonly | ref | return | sbyte | sealed | short | sizeof | stackalloc | static | string | struct | switch | this | throw | true | try | typeof | uint | ulong | unchecked | unsafe | ushort | using | virtual | void | volatile | while)
    echo "❌ '$NAME' is a reserved C# keyword. Please choose another name."
    continue
    ;;
  esac

  break
done

DIR=$(ask "Target directory" "$PWD/$NAME")

while true; do
  FRAMEWORK=$(ask "Target framework (net10.0/net9.0/net8.0)" "net10.0")
  case "$FRAMEWORK" in
  net10.0 | net9.0 | net8.0) break ;;
  *) echo "❌ Invalid framework: '$FRAMEWORK'. Please select net10.0, net9.0, or net8.0." ;;
  esac
done

SCALAR=N
ask_yn "Include Scalar API Reference?" "Y" && SCALAR=Y

TESTS=N
ask_yn "Include TUnit Tests project?" "Y" && TESTS=Y

SLN=N
ask_yn "Create solution (.sln)?" "Y" && SLN=Y

GIT=N
ask_yn "Initialize git repository?" "N" && GIT=Y

echo
echo "Summary: $NAME -> $DIR | $FRAMEWORK | Scalar=$SCALAR Tests=$TESTS sln=$SLN git=$GIT"

ask_yn "Confirm?" "Y" || {
  echo "Cancelled."
  exit 0
}

mkdir -p "$DIR"
cd "$DIR"

# Global settings
cat <<'EOF' >Directory.Build.props
<Project>
    <PropertyGroup>
        <AllowMissingPrunePackageData>true</AllowMissingPrunePackageData>
    </PropertyGroup>
</Project>
EOF

# Microsoft Testing Platform configuration
cat <<'EOF' >global.json
{
    "test": {
        "runner": "Microsoft.Testing.Platform"
    }
}
EOF

PROJS=()

API_DIR="$NAME"

if [[ $SLN == Y || $TESTS == Y ]]; then
  API_DIR="src/$NAME"
fi

echo ">> Creating API project ($API_DIR)..."

dotnet new web \
  -n "$NAME" \
  -o "$API_DIR" \
  -f "$FRAMEWORK"

# FastEndpoints
echo ">> Installing FastEndpoints..."

dotnet add "$API_DIR" package FastEndpoints

# Scalar + OpenAPI
if [[ $SCALAR == Y ]]; then
  echo ">> Installing FastEndpoints.OpenApi..."
  dotnet add "$API_DIR" package FastEndpoints.OpenApi

  echo ">> Installing Scalar.AspNetCore..."
  dotnet add "$API_DIR" package Scalar.AspNetCore
fi

PROJS+=("$API_DIR/$NAME.csproj")

# Configure Program.cs
if [[ $SCALAR == Y ]]; then

  cat <<'EOF' >"$API_DIR/Program.cs"
using FastEndpoints;
using FastEndpoints.OpenApi;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddFastEndpoints()
    .OpenApiDocument();

var app = builder.Build();

app.UseFastEndpoints();

app.MapOpenApi();

app.MapScalarApiReference();

app.Run();
EOF

else

  cat <<'EOF' >"$API_DIR/Program.cs"
using FastEndpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddFastEndpoints();

var app = builder.Build();

app.UseFastEndpoints();

app.Run();
EOF

fi

# Sample endpoint
mkdir -p "$API_DIR/Endpoints"

cat <<EOF >"$API_DIR/Endpoints/PingEndpoint.cs"
using FastEndpoints;

namespace ${NAME}.Endpoints;

public class PingEndpoint : EndpointWithoutRequest<PingResponse>
{
    public override void Configure()
    {
        Get("/api/ping");
        AllowAnonymous();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        await Send.OkAsync(
            new PingResponse("Pong", DateTime.UtcNow),
            ct);
    }
}

public record PingResponse(string Message, DateTime Timestamp);
EOF

# TUnit Test project
if [[ $TESTS == Y ]]; then

  TEST_DIR="tests/$NAME.Tests"

  echo ">> Creating TUnit test project ($TEST_DIR)..."

  dotnet new TUnit \
    -n "$NAME.Tests" \
    -o "$TEST_DIR" \
    -f "$FRAMEWORK"

  dotnet add "$TEST_DIR" reference "$API_DIR/$NAME.csproj"

  # Replace default tests
  cat <<EOF >"$TEST_DIR/PingTests.cs"
namespace ${NAME}.Tests;

public class PingTests
{
    [Test]
    public async Task PingEndpoint_ReturnsSuccess()
    {
        var timestamp = DateTime.UtcNow;

        var response = new ${NAME}.Endpoints.PingResponse(
            "Pong",
            timestamp);

        await Assert.That(response.Message).IsEqualTo("Pong");
        await Assert.That(response.Timestamp).IsEqualTo(timestamp);
    }
}
EOF

  rm -f \
    "$TEST_DIR/BasicTests.cs" \
    "$TEST_DIR/Calculator.cs" \
    "$TEST_DIR/DataDrivenTests.cs" \
    "$TEST_DIR/DependencyInjectionTests.cs" \
    "$TEST_DIR/HooksAndLifecycle.cs"

  rm -rf "$TEST_DIR/Data"

  PROJS+=("$TEST_DIR/$NAME.Tests.csproj")
fi

# Solution
if [[ $SLN == Y ]]; then

  echo ">> Creating solution..."

  dotnet new sln -n "$NAME"

  for p in "${PROJS[@]}"; do
    dotnet sln add "$p"
  done
fi

# Git
if [[ $GIT == Y ]]; then

  echo ">> Initializing Git repository..."

  git init -q
  dotnet new gitignore
fi

echo
echo "Done! Project created at: $DIR"

echo "  Run API: dotnet run --project $API_DIR"

if [[ $SCALAR == Y ]]; then
  echo "  Scalar: http://localhost:5000/scalar/v1"
fi

if [[ $TESTS == Y ]]; then
  echo "  Run Tests: dotnet test"
fi
