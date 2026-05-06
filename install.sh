#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing gitscrnsvr..."

mkdir -p ~/.local/bin ~/.config/systemd/user

cp "${SCRIPT_DIR}/gitscrnsvr" ~/.local/bin/gitscrnsvr
chmod +x ~/.local/bin/gitscrnsvr

cp "${SCRIPT_DIR}/gitscrnsvr.service" ~/.config/systemd/user/gitscrnsvr.service

systemctl --user daemon-reload

echo ""
echo "Done. Next steps:"
echo ""
echo "  1. Edit ~/.local/bin/gitscrnsvr and set REPO_PATH to a git repo"
echo "     (and optionally adjust IDLE_TIMEOUT_MS and GITLOGUE_FLAGS)"
echo ""
echo "  2. Test it manually first (triggers after 10 seconds):"
echo "     IDLE_TIMEOUT_MS=10000 ~/.local/bin/gitscrnsvr"
echo ""
echo "  3. Enable and start the background service:"
echo "     systemctl --user enable --now gitscrnsvr.service"
echo ""
echo "  4. Check logs:"
echo "     journalctl --user -u gitscrnsvr -f"
