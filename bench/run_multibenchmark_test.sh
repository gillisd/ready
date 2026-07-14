#!/usr/bin/env bash
#
# Push-button reproduction of the "ready on real CLI commands" benchmark
# (see bench/results.md). Run from anywhere:
#
#     bash bench/run_multibenchmark_test.sh
#
# It installs the target gems if missing, builds the fixtures both arms share,
# and runs `bin/bench` for each command. Override the round counts with env:
#
#     ROUNDS=15 WARMUPS=3 bash bench/run_multibenchmark_test.sh
#
# Prerequisites (the ready dev setup you already have): Ruby 4.0.1 via rbenv,
# zsh, the by/by-server gem, and `bundle install` done in this repo.
# Assumes the repo path has no spaces (the bench passes args space-separated).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/log/results"; FIX="$ROOT/log/fixtures"
mkdir -p "$OUT" "$FIX"
ROUNDS="${ROUNDS:-5}"; WARMUPS="${WARMUPS:-1}"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# --- 1. dependencies (idempotent) ------------------------------------------
say "1/4  Ensuring gems are installed"
bundle check >/dev/null 2>&1 || bundle install
for exe_gem in colorls:colorls youplot:youplot kamal:kamal codeball:codeball; do
  exe="${exe_gem%%:*}"; gem="${exe_gem##*:}"
  if command -v "$exe" >/dev/null 2>&1; then echo "  $exe: present"
  else echo "  installing $gem..."; gem install "$gem" --no-document; fi
done

# codeball needs the native filemagic gem (libmagic). Best-effort: if it won't
# load, codeball is skipped rather than failing the whole run.
CODEBALL_OK=1
if ! ruby -e "require 'filemagic'" >/dev/null 2>&1; then
  echo "  installing libmagic + ruby-filemagic (for codeball)..."
  case "$(uname -s)" in
    Darwin) command -v brew >/dev/null && brew list libmagic >/dev/null 2>&1 || brew install libmagic 2>/dev/null || true
            gem install ruby-filemagic -- --with-magic-dir="$(brew --prefix libmagic 2>/dev/null)" 2>/dev/null || true ;;
    Linux)  (dpkg -s libmagic-dev >/dev/null 2>&1 || sudo apt-get install -y libmagic-dev) 2>/dev/null || true
            gem install ruby-filemagic --no-document 2>/dev/null || true ;;
  esac
  ruby -e "require 'filemagic'" >/dev/null 2>&1 || { CODEBALL_OK=0; echo "  !! filemagic unavailable -- skipping codeball"; }
fi

# --- 2. fixtures shared by both arms ---------------------------------------
say "2/4  Building fixtures"
DATA="$FIX/youplot_data.txt"; seq 1 100 | awk '{print $1, $1^2}' > "$DATA"   # y = x^2
DIR="$ROOT/lib/ready"                                                        # colorls lists this
FILE="$ROOT/lib/ready/executable.rb"                                         # codeball packs this
echo "  data=$DATA  dir=$DIR  file=$FILE"

# --- 3. the commands (exe -> preload gems, exact args) ---------------------
declare -A PRELOAD=(
  [ri]="rdoc" [colorls]="colorls" [ronin]="ronin ronin/support"
  [youplot]="youplot" [kamal]="kamal" [codeball]="codeball"
)
declare -A ARGS=(
  [ri]="--no-pager --format=ansi TCPServer"
  [colorls]="-l $DIR"
  [ronin]="encode --hex --string rubyconf2026"
  [youplot]="line -w 50 -h 15 -t y=x^2 $DATA"
  [kamal]="accessory tree"
  [codeball]="pack $FILE"
)
ORDER=(ri colorls ronin youplot kamal codeball)
[ "$CODEBALL_OK" = 1 ] || ORDER=(ri colorls ronin youplot kamal)

# --- 4. run ----------------------------------------------------------------
say "4/4  Benchmarking ($ROUNDS rounds, $WARMUPS warmup)"
: > "$OUT/summary.txt"
for cli in "${ORDER[@]}"; do
  rf="$OUT/rf_$cli"
  { echo "gems:"; for g in ${PRELOAD[$cli]}; do echo "  - $g"; done
    echo "executables:"; echo "  - $cli"; } > "$rf"
  echo ">>> $cli ${ARGS[$cli]}"
  if ./bin/bench --readyfile "$rf" --rounds "$ROUNDS" --warmups "$WARMUPS" \
        -- "$cli" ${ARGS[$cli]} > "$OUT/out_$cli.txt" 2>&1; then
    line=$(grep -m1 'ready is [0-9]' "$OUT/out_$cli.txt" || echo '(no headline)')
    printf '  %-10s %s\n' "$cli" "$line" | tee -a "$OUT/summary.txt"
  else
    printf '  %-10s FAILED -- see %s and log/bench.log\n' "$cli" "$OUT/out_$cli.txt" | tee -a "$OUT/summary.txt"
  fi
done

say "Done. Summary:"; cat "$OUT/summary.txt"
echo; echo "Full per-command reports: $OUT/out_<cmd>.txt   |   all output: $ROOT/log/bench.log"
