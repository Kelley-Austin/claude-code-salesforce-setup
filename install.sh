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
SCRIPT_VERSION="1.5.0"
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
# Configure VS Code so company projects open ready to use
# ----------------------------------------------------------------------------
# The Salesforce extensions only work in a "trusted" workspace. By default VS
# Code shows a Workspace Trust prompt and opens untrusted folders in Restricted
# Mode (extensions disabled) — a dead end for a non-technical user. We turn the
# prompt off so projects open trusted. Done with Node (already installed) to
# safely MERGE into settings.json instead of clobbering it.
configure_vscode_trust() {
  have node || return 0
  printf '\n%s\n' "${BOLD}${BLUE}Configuring VS Code (open projects without the trust prompt)...${RESET}"
  local settings="${HOME}/Library/Application Support/Code/User/settings.json"
  local js; js="$(mktemp -t vstrust).js"
  cat > "$js" <<'NODE'
const fs = require('fs');
const path = require('path');
const p = process.argv[2];
let raw = '';
try { raw = fs.readFileSync(p, 'utf8'); } catch (e) {}
// Tolerate JSONC (settings.json may contain // and /* */ comments).
const txt = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '').trim();
let obj = {};
if (txt) {
  try { obj = JSON.parse(txt); }
  catch (e) { try { fs.copyFileSync(p, p + '.backup'); } catch (_) {} } // keep a backup if unparseable
}
obj['security.workspace.trust.enabled'] = false;
fs.mkdirSync(path.dirname(p), { recursive: true });
fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
NODE
  if node "$js" "$settings" >>"$LOG_FILE" 2>&1; then
    ok "VS Code will open company projects directly (no trust prompt)."
  else
    warn "Couldn't preconfigure VS Code trust (a one-time 'trust' prompt may appear)."
  fi
  rm -f "$js"
}

# ----------------------------------------------------------------------------
# Auto-launch: a guided window for logins, project creation and VS Code
# ----------------------------------------------------------------------------
# The Salesforce/Claude logins and the metadata retrieve all need a REAL
# interactive terminal — which a 'curl | bash' pipe doesn't provide. So we drop
# a ".command" launcher on the Desktop and open it: macOS runs it in a fresh
# Terminal window with a proper TTY. It also stays on the Desktop as a reusable
# "do my setup again" button.
launch_logins_and_vscode() {
  printf '\n%s\n' "${BOLD}${BLUE}Finishing up — opening the guided setup window...${RESET}"

  local helper="${HOME}/Desktop/Finish Claude + Salesforce Setup.command"
  cat > "$helper" <<'EOS'
#!/bin/bash
# Make the freshly installed tools available in this new window (a .command
# file does not always inherit the PATH set up in the shell profile).
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.gh-cli/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) PATH="$p:$PATH";; esac
done
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -x /usr/local/bin/brew ]    && eval "$(/usr/local/bin/brew shellenv)"
if ! command -v code >/dev/null 2>&1; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  [ -d "$CODE_BIN" ] && PATH="$PATH:$CODE_BIN"
fi
export PATH

clear
cat <<'TXT'
============================================================
   Claude Code + Salesforce — guided setup
============================================================
   Each step below is optional — pick what you need.
TXT

# ---------------- 1) Salesforce connection ----------------
ORG=""            # alias/username of the chosen org ("" = use the CLI default)
ORG_CONNECTED=0   # becomes 1 once we have a usable org
echo
echo "1) Salesforce connection"
while [ "$ORG_CONNECTED" -eq 0 ]; do
  echo
  echo "   [1] Use an org you're already logged into"
  echo "   [2] Log in to a new org"
  echo "   [3] Skip Salesforce for now"
  printf "   Choose 1, 2 or 3: "
  read -r conn
  case "$conn" in
    1)
      echo
      echo "   Reading your connected orgs..."
      ORG_LINES=""
      if command -v node >/dev/null 2>&1; then
        ORG_LINES="$(sf org list --json 2>/dev/null | node -e '
let d="";process.stdin.on("data",x=>d+=x);process.stdin.on("end",()=>{
let j;try{j=JSON.parse(d)}catch(e){process.exit(0)}
const r=(j&&j.result)||{};const seen=new Set();const out=[];
for(const k of Object.keys(r)){const a=r[k];if(Array.isArray(a)){for(const o of a){
if(o&&o.username&&!seen.has(o.username)){seen.add(o.username);out.push((o.alias||"")+"\u001f"+o.username);}}}}
process.stdout.write(out.join("\n"));})')"
      fi
      if [ -n "$ORG_LINES" ]; then
        ORG_ALIASES=(); ORG_USERS=(); ORG_LABELS=(); idx=0
        while IFS=$(printf '\037') read -r a u; do
          [ -z "$u" ] && continue
          idx=$((idx+1)); ORG_ALIASES[$idx]="$a"; ORG_USERS[$idx]="$u"
          if [ -n "$a" ]; then ORG_LABELS[$idx]="$a  ($u)"; else ORG_LABELS[$idx]="$u"; fi
        done <<EOF
$ORG_LINES
EOF
        echo
        echo "   Your connected orgs:"
        n=1; while [ "$n" -le "$idx" ]; do printf "     [%s] %s\n" "$n" "${ORG_LABELS[$n]}"; n=$((n+1)); done
        printf "   Type the number to use (blank to go back): "
        read -r num
        [ -z "$num" ] && continue
        case "$num" in *[!0-9]*) echo "   Please type a number."; continue ;; esac
        if [ "$num" -ge 1 ] && [ "$num" -le "$idx" ]; then
          ORG="${ORG_ALIASES[$num]}"; [ -z "$ORG" ] && ORG="${ORG_USERS[$num]}"
          ORG_CONNECTED=1; echo "   Using org: ${ORG_LABELS[$num]}"
        else
          echo "   That number isn't on the list. Try again."
        fi
      else
        # Fallback (no Node, or no orgs parsed): show the list and type it.
        echo "   ----------------------------------------------------------"
        sf org list
        echo "   ----------------------------------------------------------"
        printf "   Type the alias or username to use (blank to go back): "
        read -r picked
        [ -z "$picked" ] && continue
        if sf org display --target-org "$picked" >/dev/null 2>&1; then
          ORG="$picked"; ORG_CONNECTED=1; echo "   Using org: $ORG"
        else
          echo "   Couldn't find a connected org called '$picked'. Try again."
        fi
      fi
      ;;
    2)
      echo
      echo "   Which kind of org are you connecting to?"
      echo "     [1] Production / Developer    (login.salesforce.com)"
      echo "     [2] Sandbox                   (test.salesforce.com)"
      echo "     [3] Custom domain / My Domain (you'll paste the URL)"
      SF_INSTANCE=""
      while [ -z "$SF_INSTANCE" ]; do
        printf "   Type 1, 2 or 3: "
        read -r kind
        case "$kind" in
          1) SF_INSTANCE="https://login.salesforce.com" ;;
          2) SF_INSTANCE="https://test.salesforce.com" ;;
          3)
            echo "   Paste your org URL (e.g. mycompany.my.salesforce.com):"
            printf "   URL: "
            read -r url
            case "$url" in http://*|https://*) : ;; *) url="https://$url" ;; esac
            SF_INSTANCE="$url"
            ;;
          *) echo "   Please type 1, 2 or 3." ;;
        esac
      done
      echo
      echo "   Opening the browser to log in to Salesforce..."
      if sf org login web --instance-url "$SF_INSTANCE" --set-default; then
        ORG=""; ORG_CONNECTED=1   # the default org is now set
        echo "   Logged in."
      else
        echo "   Login did not complete. Try again."
      fi
      ;;
    3)
      echo "   Skipping Salesforce for now."
      break
      ;;
    *) echo "   Please choose 1, 2 or 3." ;;
  esac
done

# Build the org flag for sf commands (empty when using the CLI default).
ORG_ARGS=()
[ -n "$ORG" ] && ORG_ARGS=(--target-org "$ORG")

# ---------------- 2) Project folder (optional) ----------------
PROJECT_DIR=""
echo
echo "------------------------------------------------------------"
echo "2) Create a local project folder?"
printf "   Create one now? [Y/n]: "
read -r want_proj
case "$want_proj" in
  [Nn]*) echo "   Skipped." ;;
  *)
    name=""
    while [ -z "$name" ]; do
      printf "   Project folder name (saved in Documents): "
      read -r raw
      name="$(printf '%s' "$raw" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"
      if [ -z "$name" ]; then
        echo "   Please type a valid name (letters, numbers, - or _)."
      elif [ -e "$HOME/Documents/$name" ]; then
        echo "   A folder named '$name' already exists in Documents — pick another."
        name=""
      fi
    done
    echo
    echo "   Creating project '$name' in Documents..."
    if sf project generate --name "$name" --output-dir "$HOME/Documents"; then
      PROJECT_DIR="$HOME/Documents/$name"
      cd "$PROJECT_DIR" || PROJECT_DIR=""
    fi
    if [ -z "$PROJECT_DIR" ]; then
      echo "   Could not create the project."
    else
      # Remember the chosen org as this project's default (handy in VS Code).
      [ -n "$ORG" ] && sf config set target-org "$ORG" >/dev/null 2>&1

      # ---------------- 3) Metadata retrieve (optional) ----------------
      if [ "$ORG_CONNECTED" -eq 1 ]; then
        printf "   Download your org's metadata into this project now? [Y/n]: "
        read -r want_md
        case "$want_md" in
          [Nn]*) echo "   Skipped — empty project created. You can retrieve later." ;;
          *)
            echo "   Building a starter manifest (Apex, LWC, Aura, Objects, Flows, ...)..."
            sf project generate manifest \
              --metadata ApexClass ApexTrigger ApexPage ApexComponent \
                         LightningComponentBundle AuraDefinitionBundle \
                         CustomObject Flow Layout PermissionSet \
                         CustomTab CustomApplication StaticResource \
              --name package --output-dir manifest
            echo
            echo "   Downloading metadata (this can take a few minutes)..."
            sf project retrieve start --manifest manifest/package.xml "${ORG_ARGS[@]}"
            ;;
        esac
      else
        echo "   No Salesforce org connected — skipping metadata download."
      fi
      echo
      echo "   Project ready at: $PROJECT_DIR"
    fi
    ;;
esac

# ---------------- 4) Open VS Code ----------------
echo
if command -v code >/dev/null 2>&1; then
  if [ -n "$PROJECT_DIR" ]; then
    echo "Opening VS Code in your project..."
    code "$PROJECT_DIR"
  else
    echo "Opening VS Code..."
    code
  fi
else
  open -a "Visual Studio Code" 2>/dev/null
fi

# ---------------- 5) Claude ----------------
echo
echo "------------------------------------------------------------"
echo "3) Starting Claude..."
echo "   If asked, approve the login in your browser."
echo "   Claude will then start; you can begin typing or close this window."
echo "   (Signing in here also signs in the Claude extension in VS Code.)"
echo "------------------------------------------------------------"
echo
[ -n "$PROJECT_DIR" ] && cd "$PROJECT_DIR"
claude
EOS
  chmod +x "$helper"
  if open "$helper" >/dev/null 2>&1; then
    ok "A new Terminal window opened to finish setup (logins + project)."
    LOGINS_AUTOLAUNCHED=1
  else
    warn "Could not auto-open the setup window — do the steps manually (below)."
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
    printf '\n%s\n' "${BOLD}A new Terminal window just opened with a step-by-step menu:${RESET}"
    printf '%s\n'   "  • Salesforce: use an existing org, log in to a new one, or skip,"
    printf '%s\n'   "  • optionally create a project in Documents,"
    printf '%s\n'   "  • optionally download (retrieve) the org's metadata,"
    printf '%s\n'   "  • open VS Code, and start Claude."
    printf '%s\n'   "Each step is optional. Signing in to Claude there also signs in the"
    printf '%s\n'   "VS Code extension."
  else
    printf '\n%s\n' "${BOLD}A few one-time steps remain:${RESET}"
    printf '\n%s\n' "${BOLD}1) Connect your Salesforce org${RESET} — in a new Terminal type:  ${CYAN}sf org login web${RESET}"
    printf '%s\n'   "${BOLD}2) Sign in to Claude${RESET} — then type:  ${CYAN}claude${RESET}"
  fi

  printf '\n%s\n' "${DIM}Tip: a \"Finish Claude + Salesforce Setup\" file was placed on your"
  printf '%s\n'   "Desktop — double-click it any time to log in or create another project.${RESET}"
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
  configure_vscode_trust

  launch_logins_and_vscode
  print_next_steps
  log "=== Setup finished OK $(date) ==="
}

main "$@"
