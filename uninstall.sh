#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/gitscrnsvr"

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

echo "Uninstalling gitscrnsvr..."

if systemctl --user is-enabled --quiet gitscrnsvr.service 2>/dev/null; then
    systemctl --user disable --now gitscrnsvr.service
elif systemctl --user is-active --quiet gitscrnsvr.service 2>/dev/null; then
    systemctl --user stop gitscrnsvr.service
fi

rm -f ~/.local/bin/gitscrnsvr
rm -f ~/.config/systemd/user/gitscrnsvr.service
systemctl --user daemon-reload

echo "Removed ~/.local/bin/gitscrnsvr and the systemd user service."

if [[ -d "$CONFIG_DIR" ]]; then
    remove_config=$PURGE
    if [[ "$PURGE" == "false" ]] && [[ -t 0 ]]; then
        read -rp "Also remove config at ${CONFIG_DIR}? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] && remove_config=true
    fi
    if [[ "$remove_config" == "true" ]]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed ${CONFIG_DIR}"
    else
        echo "Left config in place: ${CONFIG_DIR}"
    fi
fi

echo "Done."
