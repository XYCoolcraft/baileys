#!/usr/bin/env bash
#
# upload-npm.sh — interactive, animated publisher for @xayz/baileys (XYCoolcraft)
#
# What this does, step by step:
#   1) Checks Node.js / npm are installed (offers to install via apt if missing)
#   2) Opens/prints the npm token page and asks you to paste an Automation token
#   3) Sets that token for the npm registry (current shell/session only)
#   4) Sanity-checks package.json and the "lib" build output
#   5) Runs `npm publish --access public`
#
# Nothing here uploads your token anywhere except to `npm config`, which talks
# only to the npm registry you're already publishing to. Read before you run it.
#
# Usage:
#   bash upload-npm.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Pretty output helpers
# ---------------------------------------------------------------------------
C_RESET="\033[0m"
C_DIM="\033[2m"
C_BOLD="\033[1m"
C_PURPLE="\033[38;5;135m"
C_GREEN="\033[38;5;77m"
C_CYAN="\033[38;5;51m"
C_YELLOW="\033[38;5;220m"
C_RED="\033[38;5;203m"

TOTAL_STEPS=5
CUR_STEP=0

banner() {
  echo -e "${C_PURPLE}${C_BOLD}"
  cat << 'EOF'
██╗  ██╗██╗   ██╗ ██████╗ ██████╗  ██████╗ ██╗      ██████╗██████╗  █████╗ ███████╗████████╗
╚██╗██╔╝╚██╗ ██╔╝██╔════╝██╔═══██╗██╔═══██╗██║     ██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
 ╚███╔╝  ╚████╔╝ ██║     ██║   ██║██║   ██║██║     ██║     ██████╔╝███████║█████╗     ██║
 ██╔██╗   ╚██╔╝  ██║     ██║   ██║██║   ██║██║     ██║     ██╔══██╗██╔══██║██╔══╝     ██║
██╔╝ ██╗   ██║   ╚██████╗╚██████╔╝╚██████╔╝███████╗╚██████╗██║  ██║██║  ██║██║        ██║
╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝
EOF
  echo -e "${C_RESET}${C_CYAN}${C_BOLD}          @xayz/baileys — npm publish assistant${C_RESET}"
  echo -e "${C_DIM}          ────────────────────────────────────────────────${C_RESET}\n"
}

# progress_bar <percent> <label>
progress_bar() {
  local percent="$1" label="$2" width=32
  local filled=$(( percent * width / 100 ))
  local empty=$(( width - filled ))
  local bar
  bar=$(printf "%${filled}s" | tr ' ' '█')
  bar+=$(printf "%${empty}s" | tr ' ' '░')
  printf "\r${C_PURPLE}[%s]${C_RESET} ${C_BOLD}%3d%%${C_RESET}  %s" "$bar" "$percent" "$label"
}

# animate_step <seconds> <label>  — smooth little progress animation for a step
animate_step() {
  local duration="$1" label="$2" steps=20
  local sleep_for
  sleep_for=$(awk -v d="$duration" -v s="$steps" 'BEGIN { printf "%.3f", d / s }')
  for i in $(seq 1 "$steps"); do
    local pct=$(( i * 100 / steps ))
    progress_bar "$pct" "$label"
    sleep "$sleep_for"
  done
  echo ""
}

step_header() {
  CUR_STEP=$((CUR_STEP + 1))
  echo -e "\n${C_CYAN}${C_BOLD}▶ Step ${CUR_STEP}/${TOTAL_STEPS} — $1${C_RESET}"
}

ok()   { echo -e "  ${C_GREEN}✔${C_RESET} $1"; }
warn() { echo -e "  ${C_YELLOW}⚠${C_RESET} $1"; }
err()  { echo -e "  ${C_RED}✘${C_RESET} $1"; }

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
clear || true
banner

# ---------------------------------------------------------------------------
# Step 1: environment check
# ---------------------------------------------------------------------------
step_header "Checking environment (Node.js / npm)"
animate_step 1.0 "Scanning system for Node.js and npm..."

NEED_INSTALL=false
if ! command -v node > /dev/null 2>&1 || ! command -v npm > /dev/null 2>&1; then
  NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
  warn "Node.js and/or npm not found."
  if command -v apt > /dev/null 2>&1; then
    read -r -p "  Install with 'apt update && apt install -y nodejs npm'? [y/N] " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      apt update
      apt install -y nodejs npm
    else
      err "Cannot continue without Node.js/npm. Exiting."
      exit 1
    fi
  else
    err "No 'apt' found. Please install Node.js + npm manually, then re-run this script."
    exit 1
  fi
fi

NODE_V="$(node -v 2>/dev/null || echo 'unknown')"
NPM_V="$(npm -v 2>/dev/null || echo 'unknown')"
ok "Node.js ${NODE_V} / npm ${NPM_V} ready"

# ---------------------------------------------------------------------------
# Step 2: npm auth token
# ---------------------------------------------------------------------------
step_header "npm authentication"
TOKEN_URL="https://www.npmjs.com/settings/$(npm whoami 2>/dev/null || echo 'YOUR_NPM_USERNAME')/tokens"
echo -e "  Open this page and create an ${C_BOLD}Automation${C_RESET} token, then paste it below:"
echo -e "  ${C_CYAN}${TOKEN_URL}${C_RESET}"
echo -e "  ${C_DIM}(If that shows 'YOUR_NPM_USERNAME', run 'npm login' first, or just replace it${C_RESET}"
echo -e "  ${C_DIM} with your actual npm username in the URL.)${C_RESET}\n"

read -r -s -p "  Paste your npm token (input hidden): " NPM_TOKEN
echo ""
if [ -z "${NPM_TOKEN:-}" ]; then
  err "No token provided. Exiting."
  exit 1
fi

animate_step 0.8 "Configuring npm registry authentication..."
npm config set "//registry.npmjs.org/:_authToken" "${NPM_TOKEN}"
ok "npm auth token configured for this environment"
unset NPM_TOKEN

# ---------------------------------------------------------------------------
# Step 3: sanity checks
# ---------------------------------------------------------------------------
step_header "Sanity-checking the package"
animate_step 0.8 "Reading package.json..."

if [ ! -f package.json ]; then
  err "No package.json in $(pwd). Run this from the package root (e.g. 'cd baileys')."
  exit 1
fi

PKG_NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "unknown")
PKG_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
ok "Package: ${C_BOLD}${PKG_NAME}@${PKG_VERSION}${C_RESET}"

animate_step 0.8 "Checking build output (lib/)..."
if [ ! -d lib ]; then
  warn "No 'lib/' directory found — publishing source as-is."
else
  ok "'lib/' build output present"
fi

echo -e "\n  ${C_DIM}Files that will be included (per package.json \"files\"):${C_RESET}"
node -p "require('./package.json').files.map(f => '   - ' + f).join('\n')" 2>/dev/null || true
echo ""
ls -la

read -r -p "  Proceed to publish ${C_BOLD}${PKG_NAME}@${PKG_VERSION}${C_RESET} to npm? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Publish cancelled by user."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 4: publish
# ---------------------------------------------------------------------------
step_header "Publishing to npm"
animate_step 1.2 "Uploading package to registry.npmjs.org..."

if npm publish --access public; then
  ok "npm publish succeeded"
else
  err "npm publish failed — see the error above (common causes: name already taken,"
  err "you're not a maintainer of this scope, or the token lacks publish rights)."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 5: done
# ---------------------------------------------------------------------------
step_header "Done"
animate_step 0.6 "Wrapping up..."

echo -e "\n${C_GREEN}${C_BOLD}"
cat << 'EOF'
  ┌─────────────────────────────────────────────┐
  │   🎉  PUBLISH COMPLETE — @xayz/baileys  🎉   │
  └─────────────────────────────────────────────┘
EOF
echo -e "${C_RESET}"
echo -e "  ${C_BOLD}${PKG_NAME}@${PKG_VERSION}${C_RESET} is now live:"
echo -e "  ${C_CYAN}https://www.npmjs.com/package/${PKG_NAME}${C_RESET}"
echo -e "\n  Install it anywhere with:"
echo -e "  ${C_DIM}npm install ${PKG_NAME}${C_RESET}\n"
