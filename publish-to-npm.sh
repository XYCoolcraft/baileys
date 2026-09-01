#!/usr/bin/env bash
#
# publish-to-npm.sh
# -----------------------------------------------------------------------
# Interactive helper that publishes any folder in this project (or any
# folder you point it at) to the npm registry.
#
# What it does, step by step:
#   1. Lets you pick which folder to publish (shows ALL files inside it,
#      including dotfiles / dotfolders, with a type label for each).
#   2. Detects whether you are already logged in to npm (npm whoami).
#      - If yes, it shows your npm username and asks to continue with it.
#      - If no, it asks for an npm access token and logs in with it.
#   3. Asks for a custom package name and version.
#   4. Updates package.json in the chosen folder with that name/version.
#   5. Runs `npm publish` for you.
#
# Usage:
#   chmod +x publish-to-npm.sh
#   ./publish-to-npm.sh
# -----------------------------------------------------------------------

set -euo pipefail

BOLD="$(tput bold 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
CYAN="$(tput setaf 6 2>/dev/null || true)"

info()  { echo "${CYAN}${BOLD}==>${RESET} $1"; }
ok()    { echo "${GREEN}${BOLD}OK${RESET}  $1"; }
warn()  { echo "${YELLOW}${BOLD}!!${RESET}  $1"; }
fail()  { echo "${RED}${BOLD}ERROR${RESET} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v npm >/dev/null 2>&1 || fail "npm is not installed or not in PATH."
command -v node >/dev/null 2>&1 || fail "node is not installed or not in PATH."

echo ""
echo "${BOLD}npm publish helper${RESET}"
echo "-----------------------------------------------------------------------"

# -------------------------------------------------------------------------
# STEP 1 - Choose which folder to publish
# -------------------------------------------------------------------------
info "Step 1 of 5 - choose the folder to publish"
echo "    Enter the path to the folder you want to publish to npm."
echo "    Press Enter to use the default: ${SCRIPT_DIR}/library"
read -r -p "    Folder path [${SCRIPT_DIR}/library]: " TARGET_DIR
TARGET_DIR="${TARGET_DIR:-${SCRIPT_DIR}/library}"
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || true)"

[ -z "$TARGET_DIR" ] && fail "That folder does not exist."
[ -f "$TARGET_DIR/package.json" ] || fail "No package.json found in $TARGET_DIR - cannot publish this folder."

echo ""
info "Contents of: ${TARGET_DIR}"
echo "    (includes hidden/dotfiles, and shows type: file / directory / symlink)"
echo "-----------------------------------------------------------------------"
# List every entry (including dotfiles/dotfolders) with a type label.
# Uses find so behavior is consistent across macOS/Linux, then sorts it.
while IFS= read -r -d '' entry; do
  rel="${entry#$TARGET_DIR/}"
  [ -z "$rel" ] && continue
  if [ -L "$entry" ]; then
    kind="symlink"
  elif [ -d "$entry" ]; then
    kind="directory"
  else
    ext="${entry##*.}"
    if [ "$ext" = "$entry" ]; then ext="(no extension)"; else ext=".$ext"; fi
    kind="file  $ext"
  fi
  printf "    %-45s %s\n" "$rel" "$kind"
done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 3 \( -name node_modules -prune \) -o -print0 | sort -z)
echo "-----------------------------------------------------------------------"
echo ""

read -r -p "    Continue publishing this folder? [Y/n]: " CONFIRM_DIR
CONFIRM_DIR="${CONFIRM_DIR:-Y}"
if [[ ! "$CONFIRM_DIR" =~ ^[Yy]$ ]]; then
  warn "Cancelled by user."
  exit 0
fi

cd "$TARGET_DIR"

# -------------------------------------------------------------------------
# STEP 2 - Detect / authenticate npm user
# -------------------------------------------------------------------------
echo ""
info "Step 2 of 5 - npm authentication"

NPM_USER="$(npm whoami 2>/dev/null || true)"

if [ -n "$NPM_USER" ]; then
  ok "Already logged in to npm as: ${BOLD}${NPM_USER}${RESET}"
  read -r -p "    Publish using this account? [Y/n]: " USE_CURRENT
  USE_CURRENT="${USE_CURRENT:-Y}"
  if [[ ! "$USE_CURRENT" =~ ^[Yy]$ ]]; then
    NPM_USER=""
  fi
fi

if [ -z "$NPM_USER" ]; then
  warn "No active npm login detected."
  echo "    You can generate an access token at: https://www.npmjs.com/settings/<your-username>/tokens"
  echo "    (Choose an 'Automation' or 'Publish' token type.)"
  read -r -s -p "    Paste your npm access token: " NPM_TOKEN
  echo ""
  [ -z "$NPM_TOKEN" ] && fail "No token provided."

  NPMRC_PATH="$TARGET_DIR/.npmrc"
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > "$NPMRC_PATH"
  ok "Wrote a temporary .npmrc with your token for this publish."

  NPM_USER="$(npm whoami 2>/dev/null || true)"
  if [ -z "$NPM_USER" ]; then
    rm -f "$NPMRC_PATH"
    fail "That token did not authenticate successfully. Aborting."
  fi
  ok "Authenticated as: ${BOLD}${NPM_USER}${RESET}"
fi

# -------------------------------------------------------------------------
# STEP 3 - Package name
# -------------------------------------------------------------------------
echo ""
info "Step 3 of 5 - package name"
CURRENT_NAME="$(node -p "require('./package.json').name" 2>/dev/null || echo "")"
read -r -p "    Package name [${CURRENT_NAME}]: " PKG_NAME
PKG_NAME="${PKG_NAME:-$CURRENT_NAME}"
[ -z "$PKG_NAME" ] && fail "Package name cannot be empty."

# -------------------------------------------------------------------------
# STEP 4 - Version
# -------------------------------------------------------------------------
echo ""
info "Step 4 of 5 - version"
CURRENT_VERSION="$(node -p "require('./package.json').version" 2>/dev/null || echo "1.0.0")"
read -r -p "    Version (semver, e.g. 1.0.0) [${CURRENT_VERSION}]: " PKG_VERSION
PKG_VERSION="${PKG_VERSION:-$CURRENT_VERSION}"

if ! [[ "$PKG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  fail "\"$PKG_VERSION\" is not a valid semver version (expected e.g. 1.0.0)."
fi

# Update package.json in place using Node (safe JSON edit, no extra deps).
node -e "
const fs = require('fs');
const pkgPath = './package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
pkg.name = '${PKG_NAME}';
pkg.version = '${PKG_VERSION}';
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
"
ok "package.json updated -> name: ${PKG_NAME}, version: ${PKG_VERSION}"

# -------------------------------------------------------------------------
# STEP 5 - Confirm and publish
# -------------------------------------------------------------------------
echo ""
info "Step 5 of 5 - publish"
echo "    About to run: npm publish --access public"
echo "    Folder:  $TARGET_DIR"
echo "    Package: ${PKG_NAME}@${PKG_VERSION}"
echo "    npm user: ${NPM_USER}"
read -r -p "    Proceed? [y/N]: " CONFIRM_PUBLISH
CONFIRM_PUBLISH="${CONFIRM_PUBLISH:-N}"

if [[ "$CONFIRM_PUBLISH" =~ ^[Yy]$ ]]; then
  npm publish --access public
  ok "Published ${PKG_NAME}@${PKG_VERSION} to npm!"
  echo "    View it at: https://www.npmjs.com/package/${PKG_NAME}"
else
  warn "Publish cancelled. package.json changes were kept."
fi

# Clean up any temporary token file we created.
if [ -f "$TARGET_DIR/.npmrc" ] && [ -n "${NPM_TOKEN:-}" ]; then
  rm -f "$TARGET_DIR/.npmrc"
  ok "Removed temporary .npmrc token file."
fi
