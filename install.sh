#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing gitscrnsvr..."
echo ""

# Dependency checks
missing=()
for cmd in git gdbus gnome-terminal systemctl curl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing required command(s): ${missing[*]}" >&2
    echo "       gitscrnsvr targets a GNOME + systemd --user desktop session." >&2
    exit 1
fi
echo "Dependencies OK: git, gdbus, gnome-terminal, systemctl, curl"

# Sourcing (rather than duplicating) gitscrnsvr's find_gitlogue keeps
# detection logic in one place. This only defines functions/variables since
# gitscrnsvr guards its own execution behind `main "$@"`.
source "${SCRIPT_DIR}/gitscrnsvr"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"

if gitlogue_path=$(find_gitlogue); then
    echo "Found gitlogue: ${gitlogue_path}"
else
    echo "WARNING: gitlogue not found on PATH or in any known install location."
    echo "         Install it before running gitscrnsvr, see: ${GITLOGUE_INSTALL_DOCS}"
    echo "         (installation continues; gitscrnsvr re-checks this at startup)"
fi
echo ""

# Install files
mkdir -p ~/.local/bin ~/.config/systemd/user "$CONFIG_DIR"

cp "${SCRIPT_DIR}/gitscrnsvr" ~/.local/bin/gitscrnsvr
chmod +x ~/.local/bin/gitscrnsvr

cp "${SCRIPT_DIR}/gitscrnsvr.service" ~/.config/systemd/user/gitscrnsvr.service

systemctl --user daemon-reload

# Configuration
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Config already exists at ${CONFIG_FILE}, leaving it untouched."
else
    default_repo="$HOME"
    if git -C "$(pwd)" rev-parse --git-dir &>/dev/null; then
        default_repo="$(pwd)"
    fi

    repo_path="$default_repo"
    if [[ -t 0 ]]; then
        read -rp "Path to a git repo for gitlogue to replay [${default_repo}]: " input
        [[ -n "$input" ]] && repo_path="$input"
    fi

    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        echo "WARNING: '${repo_path}' is not a git repository, edit ${CONFIG_FILE} before starting the service."
    fi

    cat > "$CONFIG_FILE" <<EOF
# gitscrnsvr configuration, safe to edit any time (never touched by
# 'gitscrnsvr update'). Uses : "\${VAR:=default}" so an already-exported
# shell env var still overrides whatever's set here.
# Full reference: https://github.com/PB811/git-screen-saver#configuration-reference

# Repository
: "\${REPO_PATH:=${repo_path}}"   # git repo whose history gitlogue replays

# gitlogue display flags
# Space-separated extra flags passed straight to gitlogue. See:
# https://github.com/unhappychoice/gitlogue/blob/main/docs/usage.md
#
#   --theme <NAME>         tokyo-night (default), dracula, nord, gruvbox,
#                           catppuccin, monokai, one-dark, ayu-dark,
#                           everforest, fluorite, github-dark, material,
#                           night-owl, rose-pine, solarized-dark,
#                           solarized-light, telemetry
#   --speed <MS>            typing speed, ms/char (default 30, try 10-100)
#   --order <MODE>          random (default here), asc, desc
#   --author <PATTERN>       only replay commits by a matching author
#   --after / --before <DATE>  restrict to a date range, e.g. "1 week ago"
#   --ignore <PATTERN>       skip files matching a glob (repeatable)
#   --speed-rule <GLOB:MS>   per-file-type typing speed, e.g. "*.json:5"
: "\${GITLOGUE_FLAGS:=--order random}"

# Idle timing
# : "\${IDLE_TIMEOUT_MS:=300000}"    # ms of no input before the screensaver starts (default 5 min)
# : "\${WAKE_THRESHOLD_MS:=2000}"    # idle-ms below this after launch = "you're back"
# : "\${LAUNCH_GRACE_SEC:=8}"        # seconds to ignore idle resets right after launch
# : "\${POLL_INTERVAL:=5}"           # seconds between idle checks while waiting to trigger
# : "\${WAKE_POLL_INTERVAL:=1}"      # seconds between idle checks while the screensaver is active

# Advanced
# Only needed if gitlogue is installed somewhere find_gitlogue() won't check.
# : "\${GITLOGUE:=/custom/path/to/gitlogue}"
EOF
    echo "Wrote config: ${CONFIG_FILE}"
fi

echo ""
echo "Installed $(~/.local/bin/gitscrnsvr --version)."
echo ""
echo "Next steps:"
echo ""
echo "  1. Review/edit ${CONFIG_FILE} (REPO_PATH, GITLOGUE_FLAGS, etc.)"
echo ""
echo "  2. Test it manually first (triggers after 10 seconds):"
echo "     IDLE_TIMEOUT_MS=10000 ~/.local/bin/gitscrnsvr"
echo ""
echo "  3. Enable and start the background service:"
echo "     systemctl --user enable --now gitscrnsvr.service"
echo ""
echo "  4. Check logs:"
echo "     journalctl --user -u gitscrnsvr -f"
echo ""
echo "  5. Update later with:"
echo "     gitscrnsvr update"
