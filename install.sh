#!/usr/bin/env bash
#
# Claude Code for Salesforce — One-Click Setup for macOS
# ------------------------------------------------------
# This script installs everything a non-technical user needs to run
# Claude Code with Salesforce on a Mac:
#
#   1. Xcode Command Line Tools (git + compilers)
#   2. Homebrew (the package manager that installs the rest)
#   3. Node.js (Claude Code runs on it)
#   4. Claude Code CLI
#   5. Visual Studio Code (the editor)
#   6. Salesforce CLI (sf)
#   7. Java (Temurin JDK — required by the Salesforce extensions)
#   8. VS Code extensions: Salesforce Extension Pack + Claude Code
#
# It is SAFE TO RUN MULTIPLE TIMES. Anything already installed is skipped.
#
# Usage (single command in Terminal):
#   curl -fsSL https://YOUR-HOST/install.sh | bash
#
set -u
set -o pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
SCRIPT_VERSION="1.2.0"
LOG_FILE="${HOME}/Library/Logs/claude-salesforce-setup.log"
REQUIRED_MACOS_MAJOR=13   # macOS Ventura or newer

# VS Code extension IDs
EXT_SALESFORCE="salesforce.salesforcedx-vscode"
EXT_CLAUDE="anthropic.claude-code"

# ----------------------------------------------------------------------------
# Pretty output helpers
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RESET="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"; CYAN="$(printf '\033[36m')"
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

TOTAL_STEPS=8
CURRENT_STEP=0

log()   { printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true; }
info()  { printf '%s\n' "${DIM}$*${RESET}"; log "INFO: $*"; }
ok()    { printf '%s\n' "  ${GREEN}✓${RESET} $*"; log "OK: $*"; }
warn()  { printf '%s\n' "  ${YELLOW}!${RESET} $*"; log "WARN: $*"; }
err()   { printf '%s\n' "  ${RED}✗ $*${RESET}" >&2; log "ERROR: $*"; }

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf '\n%s\n' "${BOLD}${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}] $*${RESET}"
  log "STEP ${CURRENT_STEP}/${TOTAL_STEPS}: $*"
}

banner() {
  printf '%s\n' "${BOLD}${CYAN}"
  cat <<'EOF'
  ┌──────────────────────────────────────────────────────┐
  │   Claude Code for Salesforce — Mac Setup Assistant     │
  └──────────────────────────────────────────────────────┘
EOF
  printf '%s\n' "${RESET}${DIM}  Version ${SCRIPT_VERSION} — this may take 10–20 minutes.${RESET}"
}

die() {
  err "$*"
  printf '\n%s\n' "${RED}${BOLD}Setup stopped.${RESET} A full log was saved to:"
  printf '%s\n' "  ${LOG_FILE}"
  printf '%s\n' "Please send that file to your IT/AI team for help."
  exit 1
}

# Read a y/n answer even when the script is piped via 'curl | bash'.
# Defaults to "yes" if no TTY is available.
ask_yes_no() {
  local prompt="$1" answer=""
  if [ -e /dev/tty ]; then
    printf '%s' "${YELLOW}${prompt} [Y/n] ${RESET}" >/dev/tty
    read -r answer </dev/tty || answer=""
  else
    answer="y"
  fi
  case "$answer" in
    [Nn]*) return 1 ;;
    *)     return 0 ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# Environment detection
# ----------------------------------------------------------------------------
detect_arch() {
  ARCH="$(uname -m)"
  if [ "$ARCH" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
    CHIP="Apple Silicon"
  else
    BREW_PREFIX="/usr/local"
    CHIP="Intel"
  fi
}

check_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "This installer only runs on macOS."
  fi
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  if [ "$major" -lt "$REQUIRED_MACOS_MAJOR" ] 2>/dev/null; then
    warn "Your macOS is older than recommended (need ${REQUIRED_MACOS_MAJOR}+). Continuing anyway."
  fi
}

# Make brew available in THIS shell session (so later steps can use it).
load_brew_env() {
  if [ -x "${BREW_PREFIX}/bin/brew" ]; then
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
    return 0
  fi
  return 1
}

# Persist 'brew shellenv' into the user's shell profile so it works in
# every new Terminal window afterwards.
persist_brew_path() {
  local line profile
  line="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
  for profile in "${HOME}/.zprofile" "${HOME}/.bash_profile"; do
    if [ -f "$profile" ] || [ "$profile" = "${HOME}/.zprofile" ]; then
      if ! grep -qF "$line" "$profile" 2>/dev/null; then
        printf '\n# Added by Claude Code for Salesforce setup\n%s\n' "$line" >>"$profile"
      fi
    fi
  done
}

# Whether the current user is a macOS Administrator (can use sudo).
is_admin() {
  id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin
}

# Cache sudo credentials up front. Homebrew's NONINTERACTIVE installer checks
# for sudo access non-interactively, which fails under 'curl | bash' because
# stdin is the script, not the keyboard. We read the password from the real
# terminal (/dev/tty) and start a background keep-alive so the credentials do
# not expire mid-install.
SUDO_KEEPALIVE_PID=""
prime_sudo() {
  if ! sudo -n true 2>/dev/null; then
    [ -e /dev/tty ] || return 1
    info "Administrator access is required to install Homebrew."
    info "Please type your Mac password (nothing shows as you type), then press Enter."
    local i
    for i in 1 2 3; do
      if sudo -v < /dev/tty; then break; fi
      [ "$i" -eq 3 ] && return 1
      warn "That didn't work — try again."
    done
  fi
  # Keep the sudo timestamp fresh until this script exits.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_KEEPALIVE_PID=$!
  return 0
}

# ----------------------------------------------------------------------------
# Installation steps
# ----------------------------------------------------------------------------
install_clt() {
  step "Xcode Command Line Tools (git, compilers)"
  if xcode-select -p >/dev/null 2>&1; then
    ok "Already installed."
    return 0
  fi
  info "A macOS dialog will pop up. Click \"Install\" and accept the license."
  xcode-select --install >/dev/null 2>&1 || true
  # Wait for the user to finish the GUI installer.
  printf '%s' "  Waiting for the installation to finish"
  local tries=0
  until xcode-select -p >/dev/null 2>&1; do
    printf '.'
    sleep 5
    tries=$((tries + 1))
    if [ "$tries" -gt 240 ]; then  # ~20 min
      printf '\n'
      die "Command Line Tools did not finish installing. Run this script again."
    fi
  done
  printf '\n'
  ok "Installed."
}

install_homebrew() {
  step "Homebrew (package manager)"
  if load_brew_env && have brew; then
    ok "Already installed."
  else
    if ! is_admin; then
      die "Your macOS account '${USER}' is not an Administrator, which is required
  to install Homebrew. Ask your IT team to grant admin rights to this account
  (or run the installer on an admin account), then try again."
    fi
    if ! prime_sudo; then
      die "Could not obtain administrator access (wrong password, or this account
  lacks admin rights). Confirm your account is an Administrator and try again."
    fi
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      >>"$LOG_FILE" 2>&1 || die "Homebrew installation failed. See log."
    load_brew_env || die "Homebrew installed but could not be loaded. See log."
    ok "Installed."
  fi
  persist_brew_path
  info "Updating Homebrew..."
  brew update >>"$LOG_FILE" 2>&1 || warn "brew update reported issues (continuing)."
}

# Install a brew formula or cask if missing.
brew_ensure() {
  local kind="$1" pkg="$2" label="$3"
  if [ "$kind" = "cask" ]; then
    if brew list --cask "$pkg" >/dev/null 2>&1; then
      ok "${label} already installed."; return 0
    fi
    info "Installing ${label}..."
    brew install --cask "$pkg" >>"$LOG_FILE" 2>&1 \
      || { warn "Could not install ${label} (see log). Continuing."; return 1; }
  else
    if brew list "$pkg" >/dev/null 2>&1; then
      ok "${label} already installed."; return 0
    fi
    info "Installing ${label}..."
    brew install "$pkg" >>"$LOG_FILE" 2>&1 \
      || { warn "Could not install ${label} (see log). Continuing."; return 1; }
  fi
  ok "${label} installed."
}

install_node() {
  step "Node.js (runtime for Claude Code)"
  # Respect an existing Node (even one installed outside Homebrew, e.g. from
  # nodejs.org or nvm) as long as it is recent enough. Avoids a conflicting
  # second copy.
  if have node; then
    local major
    major="$(node -v 2>/dev/null | sed -E 's/v([0-9]+).*/\1/')"
    if [ "${major:-0}" -ge 18 ] 2>/dev/null; then
      ok "Node.js already installed ($(node -v)) — keeping your existing version."
      return 0
    fi
    warn "Found Node.js $(node -v), older than v18. Installing a newer one via Homebrew."
  fi
  brew_ensure formula node "Node.js"
  load_brew_env || true
}

install_claude_code() {
  step "Claude Code CLI"
  if have claude; then
    ok "Already installed ($(claude --version 2>/dev/null | head -n1))."
    return 0
  fi
  info "Installing Claude Code via npm..."
  if ! have npm; then
    warn "npm not found yet; re-loading environment."
    load_brew_env || true
  fi
  npm install -g @anthropic-ai/claude-code >>"$LOG_FILE" 2>&1 \
    || die "Claude Code installation failed. See log."
  have claude && ok "Installed ($(claude --version 2>/dev/null | head -n1))." \
    || warn "Installed, but 'claude' is not on PATH yet (open a new Terminal)."
}

install_vscode() {
  step "Visual Studio Code (editor)"
  local app="/Applications/Visual Studio Code.app"
  # If VS Code was already installed manually (dragged into Applications),
  # keep it instead of letting Homebrew error on the existing app.
  if [ -d "$app" ]; then
    ok "Visual Studio Code already present — keeping your existing copy."
  else
    brew_ensure cask visual-studio-code "Visual Studio Code"
  fi
  # Ensure the 'code' command-line launcher is available for this session.
  if ! have code; then
    local code_bin="${app}/Contents/Resources/app/bin/code"
    if [ -x "$code_bin" ]; then
      export PATH="$PATH:$(dirname "$code_bin")"
    fi
  fi
}

install_salesforce_cli() {
  step "Salesforce CLI (sf)"
  if have sf; then
    ok "Already installed."
    return 0
  fi
  brew_ensure formula sf "Salesforce CLI" || {
    info "Falling back to npm for Salesforce CLI..."
    npm install -g @salesforce/cli >>"$LOG_FILE" 2>&1 \
      && ok "Salesforce CLI installed (npm)." \
      || warn "Could not install Salesforce CLI. See log."
  }
}

install_java() {
  step "Java (Temurin JDK — required by Salesforce extensions)"
  if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
    ok "A compatible Java is already installed."
    return 0
  fi
  brew_ensure cask temurin "Java (Temurin JDK)"
}

install_extensions() {
  step "VS Code extensions (Salesforce + Claude Code)"
  if ! have code; then
    warn "The 'code' command is not available; skipping extensions."
    warn "Open VS Code once, then re-run this script to add the extensions."
    return 0
  fi
  local ext
  for ext in "$EXT_SALESFORCE" "$EXT_CLAUDE"; do
    info "Installing extension: ${ext}"
    code --install-extension "$ext" --force >>"$LOG_FILE" 2>&1 \
      && ok "${ext}" \
      || warn "Could not install ${ext} (see log)."
  done
}

# ----------------------------------------------------------------------------
# Auto-launch: open VS Code + guide the two browser logins
# ----------------------------------------------------------------------------
# The Salesforce and Claude logins both open a browser, but they need a REAL
# interactive terminal — which a 'curl | bash' pipe doesn't provide. So we drop
# a small ".command" launcher on the Desktop and open it: macOS runs it in a
# fresh Terminal window with a proper TTY. Bonus: the file stays on the Desktop
# as a reusable "redo my logins" button.
launch_logins_and_vscode() {
  printf '\n%s\n' "${BOLD}${BLUE}Finishing up — opening VS Code and the login window...${RESET}"

  # 1) Open VS Code so the Claude Code extension loads. It shares the login
  #    done below, so it ends up signed in automatically.
  if have code; then
    code >/dev/null 2>&1 || open -a "Visual Studio Code" >/dev/null 2>&1 || true
  else
    open -a "Visual Studio Code" >/dev/null 2>&1 || true
  fi
  ok "Visual Studio Code opened."

  # 2) Write and open the interactive login helper.
  local helper="${HOME}/Desktop/Finish Claude + Salesforce Login.command"
  cat > "$helper" <<'EOS'
#!/bin/bash
clear
cat <<'TXT'
============================================================
   Final step — two quick logins (your browser will open)
============================================================
TXT
echo
echo "1) Salesforce login"
echo "   Which kind of org are you connecting to?"
echo
echo "     [1] Production / Developer   (login.salesforce.com)"
echo "     [2] Sandbox                  (test.salesforce.com)"
echo "     [3] Custom domain / My Domain (you'll paste the URL)"
echo
SF_INSTANCE=""
while true; do
  printf "   Type 1, 2 or 3 and press Enter: "
  read -r choice
  case "$choice" in
    1) SF_INSTANCE="https://login.salesforce.com"; break ;;
    2) SF_INSTANCE="https://test.salesforce.com";  break ;;
    3)
       echo
       echo "   Paste your org URL. Examples:"
       echo "     mycompany.my.salesforce.com"
       echo "     https://mycompany.sandbox.my.salesforce.com"
       printf "   URL: "
       read -r url
       case "$url" in
         http://*|https://*) : ;;
         *) url="https://$url" ;;
       esac
       SF_INSTANCE="$url"; break ;;
    *) echo "   Please type 1, 2 or 3." ;;
  esac
done
echo
echo "   Opening the browser to log in to Salesforce..."
sf org login web --instance-url "$SF_INSTANCE" --set-default
echo
echo "------------------------------------------------------------"
echo "2) Signing in to Claude..."
echo "   A browser window will open — approve the login."
echo "   Claude will then start. You can begin typing, or just close"
echo "   this window — you're already set up in VS Code."
echo "------------------------------------------------------------"
echo
claude
EOS
  chmod +x "$helper"
  if open "$helper" >/dev/null 2>&1; then
    ok "A new Terminal window opened to finish the two logins."
    LOGINS_AUTOLAUNCHED=1
  else
    warn "Could not auto-open the login window — do the logins manually (steps below)."
    LOGINS_AUTOLAUNCHED=0
  fi
}

# ----------------------------------------------------------------------------
# Final summary & next steps
# ----------------------------------------------------------------------------
print_next_steps() {
  printf '\n%s\n' "${BOLD}${GREEN}┌──────────────────────────────────────────────────────┐${RESET}"
  printf '%s\n'   "${BOLD}${GREEN}│   All done! Everything is installed. 🎉                │${RESET}"
  printf '%s\n'   "${BOLD}${GREEN}└──────────────────────────────────────────────────────┘${RESET}"

  if [ "${LOGINS_AUTOLAUNCHED:-0}" = "1" ]; then
    printf '\n%s\n' "${BOLD}VS Code is open, and a new Terminal window is guiding you through${RESET}"
    printf '%s\n'   "${BOLD}the two browser logins (Salesforce, then Claude).${RESET}"
    printf '%s\n'   "Just follow that window. Once Claude is signed in, the VS Code"
    printf '%s\n'   "extension is signed in too."
  else
    printf '\n%s\n' "${BOLD}Two quick one-time logins remain:${RESET}"
    printf '\n%s\n' "${BOLD}1) Connect your Salesforce org${RESET} — in a new Terminal type:  ${CYAN}sf org login web${RESET}"
    printf '%s\n'   "${BOLD}2) Sign in to Claude${RESET} — then type:  ${CYAN}claude${RESET}"
  fi

  printf '\n%s\n' "${DIM}Tip: a \"Finish Claude + Salesforce Login\" file was placed on your"
  printf '%s\n'   "Desktop — double-click it any time you need to log in again.${RESET}"
  printf '\n%s\n' "${DIM}Setup log: ${LOG_FILE}${RESET}"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
  : >"$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/claude-salesforce-setup.log"
  log "=== Setup started $(date) — version ${SCRIPT_VERSION} ==="

  detect_arch
  check_macos

  banner
  printf '\n%s\n' "Detected: ${BOLD}${CHIP}${RESET} Mac, macOS $(sw_vers -productVersion)."
  printf '%s\n'   "This will install the full Claude Code + Salesforce toolkit."
  if ! ask_yes_no "Continue?"; then
    printf '%s\n' "Cancelled. Nothing was changed."
    exit 0
  fi

  install_clt
  install_homebrew
  install_node
  install_claude_code
  install_vscode
  install_salesforce_cli
  install_java
  install_extensions

  launch_logins_and_vscode
  print_next_steps
  log "=== Setup finished OK $(date) ==="
}

main "$@"
