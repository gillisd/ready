#!/usr/bin/env bash
#
# jb-backend-bootstrap.sh
# ------------------------
# Idempotently install a JetBrains "remote development" IDE backend on a Linux
# server, install a fixed set of host plugins, and hand you a connection link.
# Designed to run on a fresh, short-lived machine (cloud-init, a base image, or
# `ssh host 'bash -s' < jb-backend-bootstrap.sh`).
#
# CLIENT SIDE: JetBrains is migrating Remote Development into the Toolbox App;
# JetBrains Gateway is being deprecated (still works during the transition).
# This is purely a client-side change -- the SERVER side below is identical for
# Toolbox, Gateway, or a full IDE: same backend, same remote-dev-server.sh.
# The `run` link this script prints opens in whichever client you use.
#
# No JetBrains license is needed to *install/warm up* a backend. A license is
# only checked on your LOCAL machine when the thin client actually connects.
#
# Usage:
#   ./jb-backend-bootstrap.sh                 # defaults below
#   IDE_CODE=GO PLUGINS="org.jetbrains.plugins.go" ./jb-backend-bootstrap.sh
#   MODE=run PROJECT_DIR=~/code/app ./jb-backend-bootstrap.sh
#
set -euo pipefail

# ============================ CONFIG (override via env) ======================
# Product code (releases API): IIU=IDEA Ultimate, IIC=IDEA Community,
#   PCP=PyCharm Pro, PCC=PyCharm Community, GO=GoLand, WS=WebStorm, RD=Rider,
#   CL=CLion, RM=RubyMine, PS=PhpStorm, RR=RustRover, DG=DataGrip.
IDE_CODE="${IDE_CODE:-IIU}"

# "latest" or a pinned version string, e.g. "2026.1.4". Pinning is recommended
# so Gateway's thin client version stays reproducible across machines.
IDE_VERSION="${IDE_VERSION:-latest}"

# Where the backend gets unpacked. Keyed by build so multiple builds coexist
# and re-runs are cheap no-ops.
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.jetbrains/backends}"

# The project the backend will index / serve.
PROJECT_DIR="${PROJECT_DIR:-$HOME/project}"

# Space-separated *host* plugin IDs (NOT display names). These run on the
# backend: language support, inspections, GitToolBox, etc. Find an ID on a
# plugin's Marketplace page (URL is .../plugin/<number>-<slug>) or in its
# META-INF/plugin.xml <id> tag.
#   NOTE: client-only plugins (IdeaVim, themes, keymaps) do NOT belong here —
#   install those in your local JetBrains Client / via Settings Sync instead.
PLUGINS="${PLUGINS:-}"     # e.g. "zielu.gittoolbox Pythonid org.jetbrains.plugins.go"

# run      = start a headless backend now and print a connection link + a ready
#            Toolbox deep link. Works with Toolbox, Gateway, or a full IDE.
#            Recommended for automated spin-ups.
# register = LEGACY (Gateway only): mark this backend discoverable by Gateway.
#            No effect for the Toolbox App; kept for existing Gateway users.
MODE="${MODE:-run}"

# For MODE=run only: how the client should dial back in over SSH.
SSH_HOST="${SSH_HOST:-$(hostname -f 2>/dev/null || hostname)}"
SSH_USER="${SSH_USER:-$USER}"
SSH_PORT="${SSH_PORT:-22}"
# ============================================================================

log() { printf '\033[1;34m[jb]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[jb] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

have curl || die "curl is required"
have tar  || die "tar is required"
have jq || have python3 || die "need jq (preferred) or python3 to parse the releases API"

# One scratch dir for the whole run; one EXIT trap.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Correct Python fallback parser (used only if jq is absent). Reads JSON on
# stdin — no heredoc/pipe conflict, no arg-size limit.
PYPARSE="$WORK/parse.py"
cat > "$PYPARSE" <<'PY'
import sys, json
want, pkey = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin) or {}
rels = next(iter(data.values()), [])
r = rels[0] if want == "latest" else next((x for x in rels if x.get("version") == want), None)
if not r:
    sys.exit(f"no release matching '{want}'")
dl = r.get("downloads", {}).get(pkey) or sys.exit(f"no '{pkey}' download for build {r.get('build')}")
print("\t".join([r["build"], dl["link"], dl.get("checksumLink", "")]))
PY

# --- Pick the right Linux build for this CPU architecture --------------------
case "$(uname -m)" in
  x86_64|amd64)   PLATFORM_KEY="linux" ;;
  aarch64|arm64)  PLATFORM_KEY="linuxARM64" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac

# --- Resolve build number + download link from the releases API --------------
# Emits: "<build>\t<link>\t<checksumLink>"  (curl pipes JSON to stdin either way)
resolve() {
  local url="https://data.services.jetbrains.com/products/releases?code=${IDE_CODE}&type=release"
  if have jq; then
    curl -fsSL "$url" | jq -r --arg want "$IDE_VERSION" --arg k "$PLATFORM_KEY" '
      .[] as $rels
      | (if $want == "latest" then $rels[0]
         else ($rels | map(select(.version == $want)) | .[0]) end) as $r
      | if $r == null then error("no release matching \($want)")
        else [$r.build, $r.downloads[$k].link, ($r.downloads[$k].checksumLink // "")] | @tsv
        end'
  else
    curl -fsSL "$url" | python3 "$PYPARSE" "$IDE_VERSION" "$PLATFORM_KEY"
  fi
}

log "Resolving ${IDE_CODE} ${IDE_VERSION} (${PLATFORM_KEY}) ..."
IFS=$'\t' read -r BUILD LINK SHALINK < <(resolve) \
  || die "could not resolve a release (check IDE_CODE / IDE_VERSION)"

DEST="${INSTALL_ROOT}/${IDE_CODE}-${BUILD}"
SERVER_SH="${DEST}/bin/remote-dev-server.sh"

# --- Download + extract (idempotent) -----------------------------------------
if [[ -x "$SERVER_SH" ]]; then
  log "Backend ${IDE_CODE} build ${BUILD} already present at ${DEST} — skipping download."
else
  log "Downloading ${LINK}"
  curl -fSL "$LINK" -o "$WORK/ide.tar.gz"

  if [[ -n "$SHALINK" ]]; then
    log "Verifying SHA-256 ..."
    expected="$(curl -fsSL "$SHALINK" | awk '{print $1}')"
    echo "${expected}  ${WORK}/ide.tar.gz" | sha256sum -c - >/dev/null \
      || die "checksum mismatch — aborting"
  fi

  mkdir -p "$DEST"
  # tarball has a single top-level dir (idea-IU-<build>/...); flatten it.
  tar -xzf "$WORK/ide.tar.gz" -C "$DEST" --strip-components=1
  log "Installed to ${DEST}"
fi

# Authoritative launcher product code (IU, PY, GO, ...) for Toolbox's ideHint.
# This differs from the releases-API code (IIU->IU, PCP->PY, DG->DB, ...), so
# read it from the backend itself rather than guessing.
if have jq; then
  PRODUCT_CODE="$(jq -r '.productCode' "${DEST}/product-info.json" 2>/dev/null || echo "$IDE_CODE")"
else
  PRODUCT_CODE="$(python3 -c "import json;print(json.load(open('${DEST}/product-info.json'))['productCode'])" 2>/dev/null || echo "$IDE_CODE")"
fi

# --- Install host plugins ----------------------------------------------------
# Real signature is: remote-dev-server.sh installPlugins <PROJECT_PATH> <IDs...>
# (JetBrains' docs omit the project path, but the backend requires it.)
if [[ -n "${PLUGINS// /}" ]]; then
  mkdir -p "$PROJECT_DIR"
  log "Installing host plugins: ${PLUGINS}"
  # shellcheck disable=SC2086
  "$SERVER_SH" installPlugins "$PROJECT_DIR" $PLUGINS \
    || die "plugin install failed (check plugin IDs and network access to Marketplace)"
fi

# --- Make it usable ----------------------------------------------------------
case "$MODE" in
  run)
    mkdir -p "$PROJECT_DIR"
    # Toolbox deep link: click it locally to SSH in and open the project.
    # (Toolbox still handles the historical jetbrains://gateway/ssh/... scheme.)
    TOOLBOX_LINK="jetbrains://gateway/ssh/environment?h=${SSH_HOST}&u=${SSH_USER}&p=${SSH_PORT}&launchIde=true&ideHint=${PRODUCT_CODE}-${BUILD}&projectHint=${PROJECT_DIR}"
    log "Toolbox one-click connect (open on your LOCAL machine):"
    log "  ${TOOLBOX_LINK}"
    log ""
    log "Starting headless backend for ${PROJECT_DIR} ..."
    log "The command below also prints a jetbrains:// join link — open it in"
    log "the Toolbox App, Gateway, or any full JetBrains IDE."
    export REMOTE_DEV_NON_INTERACTIVE=1
    exec "$SERVER_SH" run "$PROJECT_DIR" \
      --ssh-link-host "$SSH_HOST" \
      --ssh-link-user "$SSH_USER" \
      --ssh-link-port "$SSH_PORT"
    ;;
  register)
    # Legacy path for users still on JetBrains Gateway. No effect for Toolbox.
    log "[legacy] Registering backend with JetBrains Gateway ..."
    "$SERVER_SH" registerBackendLocationForGateway
    log "Done. In Gateway: SSH into this host and pick build ${BUILD} from the list."
    log "If you use the Toolbox App instead, skip this — just SSH to the host in"
    log "Toolbox, or use MODE=run to get a connection link."
    ;;
  *)
    die "unknown MODE '$MODE' (use 'run' or 'register')"
    ;;
esac
