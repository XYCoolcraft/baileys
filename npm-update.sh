#!/usr/bin/env bash
#
# npm-update.sh — bump the version and republish, WITHOUT touching any other file
#
# Unlike a fresh setup, this script never re-downloads, re-generates, or
# overwrites your source. It only:
#   1) Bumps the "version" field in package.json (via `npm version`, using
#      --no-git-tag-version so it works even without a git repo / with git
#      unavailable — it just edits the JSON field, nothing else).
#   2) Shows you exactly what will be included in the published tarball
#      (npm pack --dry-run) so you can eyeball it before anything is sent.
#   3) Publishes that version to npm, with the same animated flow as
#      upload-npm.sh.
#
# Use this for routine version bumps after you've edited the code yourself.
# Use upload-npm.sh for a first-time publish, and vendor-libsignal.sh
# separately if you need to fix/re-point the "libsignal" github: dependency.
#
# Usage:
#   bash npm-update.sh
#
set -euo pipefail

C_RESET="\033[0m"; C_DIM="\033[2m"; C_BOLD="\033[1m"
C_PURPLE="\033[38;5;135m"; C_GREEN="\033[38;5;77m"; C_CYAN="\033[38;5;51m"
C_YELLOW="\033[38;5;220m"; C_RED="\033[38;5;203m"

TOTAL_STEPS=5
CUR_STEP=0

banner() {
  echo -e "${C_PURPLE}${C_BOLD}"
  cat << 'EOF'
 _   _ ____  __  __       _   _ ____  ____   _  _____ _____
| \ | |  _ \|  \/  |     | | | |  _ \|  _ \ / \|_   _| ____|
|  \| | |_) | |\/| |_____| | | | |_) | | | / _ \ | | |  _|
| |\  |  __/| |  | |_____| |_| |  __/| |_| / ___ \| | | |___
|_| \_|_|   |_|  |_|      \___/|_|   |____/_/   \_\_| |_____|
EOF
  echo -e "${C_RESET}${C_CYAN}${C_BOLD}   npm-update.sh — version bump + publish, no file overwrites${C_RESET}"
  echo -e "${C_DIM}   ─────────────────────────────────────────────────────────────${C_RESET}\n"
}

progress_bar() {
  local percent="$1" label="$2" width=32
  local filled=$(( percent * width / 100 )) empty
  empty=$(( width - filled ))
  local bar; bar=$(printf "%${filled}s" | tr ' ' '█'); bar+=$(printf "%${empty}s" | tr ' ' '░')
  printf "\r${C_PURPLE}[%s]${C_RESET} ${C_BOLD}%3d%%${C_RESET}  %s" "$bar" "$percent" "$label"
}

animate_step() {
  local duration="$1" label="$2" steps=16 sleep_for
  sleep_for=$(awk -v d="$duration" -v s="$steps" 'BEGIN { printf "%.3f", d / s }')
  for i in $(seq 1 "$steps"); do
    progress_bar $(( i * 100 / steps )) "$label"
    sleep "$sleep_for"
  done
  echo ""
}

step_header() { CUR_STEP=$((CUR_STEP + 1)); echo -e "\n${C_CYAN}${C_BOLD}▶ Step ${CUR_STEP}/${TOTAL_STEPS} — $1${C_RESET}"; }
ok()   { echo -e "  ${C_GREEN}✔${C_RESET} $1"; }
warn() { echo -e "  ${C_YELLOW}⚠${C_RESET} $1"; }
err()  { echo -e "  ${C_RED}✘${C_RESET} $1"; }

clear || true
banner

# ---------------------------------------------------------------------------
# Step 1: locate package.json + show current state
# ---------------------------------------------------------------------------
step_header "Reading current package"
if [ ! -f package.json ]; then
  err "No package.json in $(pwd). Run this from your project root."
  exit 1
fi
if ! command -v node > /dev/null 2>&1 || ! command -v npm > /dev/null 2>&1; then
  err "node/npm not found. Install them first (see upload-npm.sh step 1)."
  exit 1
fi

animate_step 0.5 "Parsing package.json..."
PKG_NAME=$(node -p "require('./package.json').name")
CUR_VERSION=$(node -p "require('./package.json').version")
ok "Current: ${C_BOLD}${PKG_NAME}@${CUR_VERSION}${C_RESET}"

if node -e "process.exit(require('./package.json').dependencies?.libsignal?.startsWith('github:') ? 0 : 1)" 2>/dev/null; then
  warn "dependencies.libsignal still uses a 'github:' spec — that needs git to install."
  warn "If that's failing for you, run 'bash vendor-libsignal.sh' first (separate script)."
fi

# ---------------------------------------------------------------------------
# Step 2: choose the new version — package.json is the ONLY file this edits
# ---------------------------------------------------------------------------
step_header "Choose the new version"
echo -e "  ${C_DIM}This step edits ONLY the \"version\" field in package.json.${C_RESET}"
echo -e "  ${C_DIM}No source files, no lib/, no README — nothing else is touched.${C_RESET}\n"
echo "  1) patch  (${CUR_VERSION} -> bugfix bump)"
echo "  2) minor  (${CUR_VERSION} -> new feature bump)"
echo "  3) major  (${CUR_VERSION} -> breaking change bump)"
echo "  4) custom (type an exact version)"
read -r -p "  Choice [1-4]: " BUMP_CHOICE

case "$BUMP_CHOICE" in
  1) BUMP_TYPE="patch" ;;
  2) BUMP_TYPE="minor" ;;
  3) BUMP_TYPE="major" ;;
  4)
    read -r -p "  New version (e.g. 1.2.3): " CUSTOM_VERSION
    BUMP_TYPE="custom"
    ;;
  *) err "Invalid choice."; exit 1 ;;
esac

animate_step 0.6 "Bumping version..."
if [ "$BUMP_TYPE" = "custom" ]; then
  npm pkg set "version=${CUSTOM_VERSION}" > /dev/null
else
  # --no-git-tag-version: works with or without a git repo present, and
  # guarantees this touches package.json (and package-lock.json, if it
  # exists) ONLY — no commit, no tag, no other file changes.
  npm version "$BUMP_TYPE" --no-git-tag-version --allow-same-version > /dev/null
fi
NEW_VERSION=$(node -p "require('./package.json').version")
ok "Version bumped: ${CUR_VERSION} → ${C_BOLD}${NEW_VERSION}${C_RESET}"

# ---------------------------------------------------------------------------
# Step 3: show exactly what would be published — nothing written yet
# ---------------------------------------------------------------------------
step_header "Previewing the publish (dry run, writes nothing)"
animate_step 0.6 "Building file list..."
echo -e "  ${C_DIM}Files npm would include in ${PKG_NAME}@${NEW_VERSION}:${C_RESET}"
npm pack --dry-run 2>&1 | sed 's/^/   /'

read -r -p "  Proceed to publish ${C_BOLD}${PKG_NAME}@${NEW_VERSION}${C_RESET}? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Publish cancelled. package.json version stays at ${NEW_VERSION}"
  warn "(revert manually with: npm pkg set version=${CUR_VERSION})"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 4: npm auth
# ---------------------------------------------------------------------------
step_header "npm authentication"
TOKEN_URL="https://www.npmjs.com/settings/$(npm whoami 2>/dev/null || echo 'YOUR_NPM_USERNAME')/tokens"
echo -e "  Need a token? ${C_CYAN}${TOKEN_URL}${C_RESET}"
read -r -s -p "  Paste your npm token (input hidden, leave blank to reuse existing auth): " NPM_TOKEN
echo ""
if [ -n "${NPM_TOKEN:-}" ]; then
  npm config set "//registry.npmjs.org/:_authToken" "${NPM_TOKEN}"
  ok "npm auth token updated"
fi
unset NPM_TOKEN

# ---------------------------------------------------------------------------
# Step 5: publish
# ---------------------------------------------------------------------------
step_header "Publishing ${PKG_NAME}@${NEW_VERSION}"
animate_step 1.0 "Uploading to registry.npmjs.org..."

if npm publish --access public; then
  ok "Published successfully"
else
  err "npm publish failed — package.json is still at version ${NEW_VERSION}."
  err "Fix the issue above and re-run this script, or revert with:"
  err "  npm pkg set version=${CUR_VERSION}"
  exit 1
fi

echo -e "\n${C_GREEN}${C_BOLD}"
cat << 'EOF'
  ┌─────────────────────────────────────────────┐
  │   🎉  VERSION UPDATED & PUBLISHED  🎉        │
  └─────────────────────────────────────────────┘
EOF
echo -e "${C_RESET}"
echo -e "  ${C_BOLD}${PKG_NAME}${C_RESET}: ${CUR_VERSION} → ${C_BOLD}${NEW_VERSION}${C_RESET}"
echo -e "  ${C_CYAN}https://www.npmjs.com/package/${PKG_NAME}${C_RESET}"
echo -e "\n  Update it anywhere with:"
echo -e "  ${C_DIM}npm install ${PKG_NAME}@${NEW_VERSION}${C_RESET}\n"
