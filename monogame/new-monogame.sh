#!/usr/bin/env bash
# Creates MonoGame (C#) projects for Desktop, Android and iOS.
# Usage: ./new-monogame.sh   (Enter accepts the default value in brackets)

set -euo pipefail

ask() { # ask "question" "default" -> echoes reply
  local reply
  read -r -p "$1 [$2]: " reply
  echo "${reply:-$2}"
}

ask_yn() { # ask_yn "question" "Y|N"
  local r
  r=$(ask "$1 (y/n)" "$2")
  case "$(echo "$r" | tr '[:upper:]' '[:lower:]')" in y|yes) return 0 ;; *) return 1 ;; esac
}

command -v dotnet >/dev/null || { echo "dotnet SDK not found."; exit 1; }

# Install MonoGame templates if needed
if ! dotnet new list mgdesktopgl 2>/dev/null | grep -q mgdesktopgl; then
  echo "Installing MonoGame templates..."
  dotnet new install MonoGame.Templates.CSharp
fi

echo "=== New MonoGame Project ==="
NAME=$(ask "Game name" "MyGame")
NAME=${NAME// /}
DIR=$(ask "Target directory" "$PWD/$NAME")
FRAMEWORK=$(ask "Target framework (net8.0/net9.0/net10.0)" "net8.0")

DESKTOP=N; ANDROID=N; IOS=N
ask_yn "Create Desktop project (Windows/Linux/macOS)?" "Y" && DESKTOP=Y
ask_yn "Create Android project?" "Y" && ANDROID=Y
ask_yn "Create iOS project?" "Y" && IOS=Y

if [[ $DESKTOP == N && $ANDROID == N && $IOS == N ]]; then
  echo "No platform selected."; exit 1
fi

SLN=N
ask_yn "Create solution (.sln) grouping projects?" "Y" && SLN=Y
GIT=N
ask_yn "Initialize git repository?" "N" && GIT=Y

echo
echo "Summary: $NAME -> $DIR | $FRAMEWORK | Desktop=$DESKTOP Android=$ANDROID iOS=$IOS sln=$SLN git=$GIT"
ask_yn "Confirm?" "Y" || { echo "Cancelled."; exit 0; }

mkdir -p "$DIR"
cd "$DIR"

create() { # create template suffix
  local proj="$NAME.$2"
  echo ">> Creating $proj ($1)"
  dotnet new "$1" -n "$proj" -o "$proj" -f "$FRAMEWORK" 2>/dev/null \
    || dotnet new "$1" -n "$proj" -o "$proj"
  PROJS+=("$proj/$proj.csproj")
}

PROJS=()
[[ $DESKTOP == Y ]] && create mgdesktopgl Desktop
[[ $ANDROID == Y ]] && create mgandroid Android
[[ $IOS == Y ]]     && create mgios iOS

if [[ $SLN == Y ]]; then
  dotnet new sln -n "$NAME" >/dev/null
  for p in "${PROJS[@]}"; do dotnet sln add "$p"; done
fi

if [[ $GIT == Y ]]; then
  git init -q
  dotnet new gitignore >/dev/null
fi

echo
echo "Done! Project created at: $DIR"
[[ $DESKTOP == Y ]] && echo "  Desktop: dotnet run --project $NAME.Desktop"
[[ $ANDROID == Y ]] && echo "  Android: dotnet workload install android && dotnet build $NAME.Android"
[[ $IOS == Y ]]     && echo "  iOS:     dotnet workload install ios (requires macOS + Xcode)"
