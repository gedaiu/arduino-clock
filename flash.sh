#!/usr/bin/env bash
# Compiles the clock sketch and uploads it to the Arduino.
# First run bootstraps a local arduino-cli + the AVR core + NeoPixel lib.
# Overridable: FQBN, PORT. Pass "compile" as the first arg to skip uploading.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKETCH_DIR="${SKETCH:-$ROOT/arduino/clock}"
TOOLS_DIR="$ROOT/arduino/bin"
ARDUINO_CLI="$TOOLS_DIR/arduino-cli"

FQBN="${FQBN:-}"          # empty => auto-detect from the attached board
PORT="${PORT:-}"
MODE="${1:-upload}"

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

resolve_cli() {
  have arduino-cli && { ARDUINO_CLI="$(command -v arduino-cli)"; return; }
  [[ -x "$ARDUINO_CLI" ]] && return

  have curl || die "need either arduino-cli or curl on PATH to bootstrap it"
  echo ">> arduino-cli missing — vendoring it into $TOOLS_DIR (no sudo)"
  mkdir -p "$TOOLS_DIR"
  curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
    | BINDIR="$TOOLS_DIR" sh
  [[ -x "$ARDUINO_CLI" ]] || die "bootstrap failed"
}

ensure_core() {
  "$ARDUINO_CLI" core list 2>/dev/null | grep -q '^arduino:avr' && return
  echo ">> installing arduino:avr core (first run only, this pulls the toolchain)"
  "$ARDUINO_CLI" core update-index
  "$ARDUINO_CLI" core install arduino:avr
}

ensure_lib() {
  "$ARDUINO_CLI" lib list 2>/dev/null | grep -qi 'Adafruit NeoPixel' && return
  echo ">> installing Adafruit NeoPixel library"
  "$ARDUINO_CLI" lib install "Adafruit NeoPixel"
}

# Ask the board what it actually is, so we never upload with the wrong core again.
detect_board() {
  local listing
  listing="$("$ARDUINO_CLI" board list 2>/dev/null | grep -E '/dev/tty(ACM|USB)' | head -n1 || true)"
  [[ -z "$PORT" ]] && PORT="$(echo "$listing" | grep -oE '/dev/tty(ACM|USB)[0-9]+' | head -n1 || true)"
  [[ -z "$FQBN" ]] && FQBN="$(echo "$listing" | grep -oE 'arduino:avr:[a-z0-9_]+' | head -n1 || true)"
  [[ -z "$FQBN" ]] && FQBN="arduino:avr:uno"
  return 0
}

resolve_cli
detect_board
ensure_core
ensure_lib

echo ">> compiling $SKETCH_DIR for $FQBN"
"$ARDUINO_CLI" compile --fqbn "$FQBN" "$SKETCH_DIR"

[[ "$MODE" == "compile" ]] && { echo ">> compile-only: done"; exit 0; }

[[ -n "$PORT" ]] || die "no board found — plug it in or run with PORT=/dev/ttyACM0"

# The D server holds the serial port exclusively; the upload fails "busy" unless we free it.
if pgrep -x clock >/dev/null 2>&1; then
  echo ">> stopping the running 'clock' server so it releases $PORT"
  pkill -x clock || true
  sleep 1
fi

echo ">> uploading to $PORT ($FQBN)"
"$ARDUINO_CLI" upload -p "$PORT" --fqbn "$FQBN" "$SKETCH_DIR"
echo ">> done. shiny. restart the server when ready:  ./clock"
