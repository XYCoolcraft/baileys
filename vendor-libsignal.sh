#!/usr/bin/env bash
#
# vendor-libsignal.sh — rescue the "libsignal" dependency without git
#
# Problem this solves:
#   package.json currently has:
#     "libsignal": "github:tenka-san/libsignal-node"
#   `github:` dependency specs need a working `git` binary for npm to install
#   them. If `git` isn't available/usable in your environment, that install
#   step fails. This script instead:
#
#     1) Downloads the exact same source as a plain .tar.gz over HTTPS from
#        codeload.github.com (GitHub's tarball CDN — no git required at all).
#     2) Renames/repackages it under YOUR OWN npm scope (default:
#        @xayz/libsignal-node), keeping its original GPL-3.0 LICENSE file and
#        crediting the upstream repo, and publishes it to the npm registry.
#     3) Rewrites the "libsignal" line in your project's package.json to use
#        an npm alias pointing at your new package, e.g.:
#          "libsignal": "npm:@xayz/libsignal-node@^2.0.1"
#        Your source code keeps doing `import * as libsignal from 'libsignal'`
#        completely unchanged — only the dependency's *source* changes, not
#        how it's imported.
#
# Note: the npm registry already has an UNRELATED package literally called
# "libsignal" (a different project, currently v6.x). We deliberately do NOT
# publish under that name — we publish under your own scope and alias it,
# so there's no naming collision or confusion with that other package.
#
# License note: tenka-san/libsignal-node is licensed GPL-3.0, not MIT. This
# script republishes it unmodified (redistribution is explicitly allowed by
# GPL-3.0) and keeps its LICENSE file + attribution intact. This script gives
# you the facts, not legal advice — if GPL implications matter for how you
# ship your own project, it's worth a proper look on your end.
#
# Usage:
#   bash vendor-libsignal.sh
#
set -euo pipefail

C_RESET="\033[0m"; C_DIM="\033[2m"; C_BOLD="\033[1m"
C_PURPLE="\033[38;5;135m"; C_GREEN="\033[38;5;77m"; C_CYAN="\033[38;5;51m"
C_YELLOW="\033[38;5;220m"; C_RED="\033[38;5;203m"

TOTAL_STEPS=6
CUR_STEP=0

REPO_OWNER="tenka-san"
REPO_NAME="libsignal-node"
REPO_BRANCH="main"
TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_BRANCH}"

banner() {
  echo -e "${C_PURPLE}${C_BOLD}"
  cat << 'EOF'
 __     __              _              _ _ _
 \ \   / /__ _ __   __| | ___  _ __  | (_) |__
  \ \ / / _ \ '_ \ / _` |/ _ \| '__| | | | '_ \
   \ V /  __/ | | | (_| | (_) | |    | | | |_) |
    \_/ \___|_| |_|\__,_|\___/|_|    |_|_|_.__/
EOF
  echo -e "${C_RESET}${C_CYAN}${C_BOLD}   vendor-libsignal.sh — rescue a github: dep without git${C_RESET}"
  echo -e "${C_DIM}   ───────────────────────────────────────────────────────${C_RESET}\n"
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
# Step 1: tooling check
# ---------------------------------------------------------------------------
step_header "Checking tools (curl, tar, node, npm — no git needed)"
animate_step 0.6 "Scanning system..."
for bin in curl tar node npm; do
  if ! command -v "$bin" > /dev/null 2>&1; then
    err "'$bin' not found. Please install it and re-run."
    exit 1
  fi
done
ok "curl, tar, node, npm all present (git is NOT required by this script)"

# ---------------------------------------------------------------------------
# Step 2: download tarball over HTTPS
# ---------------------------------------------------------------------------
step_header "Downloading ${REPO_OWNER}/${REPO_NAME} (HTTPS tarball, no git)"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
echo -e "  ${C_DIM}${TARBALL_URL}${C_RESET}"
animate_step 0.8 "Fetching tarball from codeload.github.com..."
if ! curl -fsSL "$TARBALL_URL" -o "$WORKDIR/src.tar.gz"; then
  err "Download failed. Check your network / the repo may have moved or been renamed."
  exit 1
fi
ok "Downloaded $(du -h "$WORKDIR/src.tar.gz" | cut -f1) tarball"

animate_step 0.5 "Extracting..."
tar -xzf "$WORKDIR/src.tar.gz" -C "$WORKDIR"
SRC_DIR=$(find "$WORKDIR" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n1)
if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/package.json" ]; then
  err "Extracted contents don't look like a valid npm package (no package.json found)."
  exit 1
fi
ORIG_NAME=$(node -p "require('$SRC_DIR/package.json').name" 2>/dev/null || echo "unknown")
ORIG_VERSION=$(node -p "require('$SRC_DIR/package.json').version" 2>/dev/null || echo "0.0.0")
ORIG_LICENSE=$(node -p "require('$SRC_DIR/package.json').license" 2>/dev/null || echo "unknown")
ok "Extracted: ${ORIG_NAME}@${ORIG_VERSION} (license: ${ORIG_LICENSE})"

if [ "$ORIG_LICENSE" = "GPL-3.0" ]; then
  warn "This dependency is GPL-3.0 licensed — different from this project's MIT license."
  warn "We keep its LICENSE file + attribution intact when republishing (see script header)."
fi

# ---------------------------------------------------------------------------
# Step 3: choose new package name / version
# ---------------------------------------------------------------------------
step_header "Choose where to publish it"
read -r -p "  New package name [default: @xayz/libsignal-node]: " NEW_NAME
NEW_NAME="${NEW_NAME:-@xayz/libsignal-node}"
read -r -p "  Version to publish [default: ${ORIG_VERSION}]: " NEW_VERSION
NEW_VERSION="${NEW_VERSION:-$ORIG_VERSION}"
ok "Will publish as ${C_BOLD}${NEW_NAME}@${NEW_VERSION}${C_RESET}"

# ---------------------------------------------------------------------------
# Step 4: rewrite package.json + add provenance note (no other files touched)
# ---------------------------------------------------------------------------
step_header "Preparing package for publish"
animate_step 0.6 "Rewriting package.json..."
node -e "
const fs = require('fs');
const path = '$SRC_DIR/package.json';
const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
pkg.name = '$NEW_NAME';
pkg.version = '$NEW_VERSION';
pkg.description = (pkg.description || '') + ' (republished mirror, vendored via vendor-libsignal.sh)';
pkg.originalPackage = { name: '$ORIG_NAME', version: '$ORIG_VERSION', repository: 'https://github.com/${REPO_OWNER}/${REPO_NAME}' };
fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
"
cat >> "$SRC_DIR/README.md" << EOF

---

> **Note:** this is an unmodified mirror of [\`${REPO_OWNER}/${REPO_NAME}\`](https://github.com/${REPO_OWNER}/${REPO_NAME}),
> republished as \`${NEW_NAME}\` because the original is only distributed via GitHub (no plain
> npm-registry install), which breaks in environments without a working \`git\` binary. Original
> license (GPL-3.0) and copyright are unchanged — see LICENSE in this package.
EOF
ok "package.json + README updated (only inside the vendored copy — your project files untouched)"

echo -e "\n  ${C_DIM}Files that will be published:${C_RESET}"
(cd "$SRC_DIR" && npm pack --dry-run 2>&1 | sed 's/^/   /')

read -r -p "  Proceed to publish ${C_BOLD}${NEW_NAME}@${NEW_VERSION}${C_RESET}? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Cancelled — nothing was published or changed."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 5: npm auth + publish
# ---------------------------------------------------------------------------
step_header "Publishing ${NEW_NAME} to npm"
TOKEN_URL="https://www.npmjs.com/settings/$(npm whoami 2>/dev/null || echo 'YOUR_NPM_USERNAME')/tokens"
echo -e "  Open this page and create an ${C_BOLD}Automation${C_RESET} token if you don't have one:"
echo -e "  ${C_CYAN}${TOKEN_URL}${C_RESET}\n"
read -r -s -p "  Paste your npm token (input hidden): " NPM_TOKEN
echo ""
if [ -z "${NPM_TOKEN:-}" ]; then
  err "No token provided. Exiting."
  exit 1
fi
npm config set "//registry.npmjs.org/:_authToken" "${NPM_TOKEN}"
unset NPM_TOKEN
animate_step 1.0 "Uploading to registry.npmjs.org..."

SCOPE_ACCESS_FLAG="--access public"
if [[ "$NEW_NAME" != @*/* ]]; then
  SCOPE_ACCESS_FLAG=""
fi

if (cd "$SRC_DIR" && npm publish $SCOPE_ACCESS_FLAG); then
  ok "Published ${NEW_NAME}@${NEW_VERSION}"
else
  err "Publish failed — see the error above."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 6: patch the parent project's package.json (only the "libsignal" line)
# ---------------------------------------------------------------------------
step_header "Pointing your project at the new package"
PARENT_PKG="./package.json"
if [ -f "$PARENT_PKG" ] && node -e "process.exit(require('$PARENT_PKG').dependencies?.libsignal ? 0 : 1)" 2>/dev/null; then
  animate_step 0.5 "Updating the \"libsignal\" line in package.json..."
  node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('$PARENT_PKG', 'utf8'));
  pkg.dependencies.libsignal = 'npm:${NEW_NAME}@^${NEW_VERSION}';
  fs.writeFileSync('$PARENT_PKG', JSON.stringify(pkg, null, 2) + '\n');
  "
  ok "package.json now has: \"libsignal\": \"npm:${NEW_NAME}@^${NEW_VERSION}\""
  echo -e "  ${C_DIM}No source files changed — 'import ... from \"libsignal\"' keeps working as-is.${C_RESET}"
  echo -e "  ${C_DIM}Run 'npm install' to pick up the new resolution.${C_RESET}"
else
  warn "Couldn't find a \"libsignal\" entry in ./package.json — run this script from your"
  warn "project root, or manually set: \"libsignal\": \"npm:${NEW_NAME}@^${NEW_VERSION}\""
fi

echo -e "\n${C_GREEN}${C_BOLD}"
cat << 'EOF'
  ┌───────────────────────────────────────────────┐
  │   ✅  libsignal dependency rescued — no git    │
  └───────────────────────────────────────────────┘
EOF
echo -e "${C_RESET}"
echo -e "  ${C_CYAN}https://www.npmjs.com/package/${NEW_NAME}${C_RESET}\n"
