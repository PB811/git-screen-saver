#!/usr/bin/env bash
# Regression tests for ../install.sh and ../uninstall.sh, run against a
# scratch HOME so nothing touches the real machine's config or systemd units.

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# `systemctl --user` talks to the already-running, real user systemd manager
# regardless of $HOME/$XDG_RUNTIME_DIR overrides in the invoking process, so
# a real systemctl on PATH here would enable/disable/stop the actual
# gitscrnsvr.service on the machine running these tests. Stub it out and put
# the stub first on PATH for every install.sh/uninstall.sh invocation below.
FAKE_SYSTEMCTL_DIR=$(mktemp -d)
cat > "${FAKE_SYSTEMCTL_DIR}/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >> "${FAKE_SYSTEMCTL_LOG:-/dev/null}"
case "$*" in
    *is-enabled*|*is-active*) exit 1 ;;  # "not installed" until a real test says otherwise
    *) exit 0 ;;
esac
EOF
chmod +x "${FAKE_SYSTEMCTL_DIR}/systemctl"

run_install() {
    env -u XDG_CONFIG_HOME -u XDG_RUNTIME_DIR HOME="$SCRATCH_HOME" \
        PATH="${FAKE_SYSTEMCTL_DIR}:${PATH}" \
        bash "${REPO_ROOT}/install.sh" "$@"
}

run_uninstall() {
    env -u XDG_CONFIG_HOME -u XDG_RUNTIME_DIR HOME="$SCRATCH_HOME" \
        PATH="${FAKE_SYSTEMCTL_DIR}:${PATH}" \
        bash "${REPO_ROOT}/uninstall.sh" "$@"
}

echo "--- install.sh: missing dependency is reported and aborts ---"
SCRATCH_HOME=$(new_scratch_home)
# A PATH with everything real install.sh needs symlinked in (the systemctl
# stub, plus real git/gnome-terminal/curl/coreutils), except gdbus, to
# simulate that one dependency being missing without faking the rest.
fake_bin=$(mktemp -d)
for cmd in git gnome-terminal curl dirname mkdir cp chmod cat bash; do
    real="$(command -v "$cmd")"
    ln -s "$real" "${fake_bin}/${cmd}"
done
ln -s "${FAKE_SYSTEMCTL_DIR}/systemctl" "${fake_bin}/systemctl"
out=$(env -u XDG_CONFIG_HOME -u XDG_RUNTIME_DIR HOME="$SCRATCH_HOME" PATH="$fake_bin" \
    bash "${REPO_ROOT}/install.sh" 2>&1 < /dev/null)
status=$?
assert_status 1 "$status" "install.sh exits 1 when a dependency is missing"
assert_contains "$out" "gdbus" "reports which dependency is missing"
rm -rf "$fake_bin" "$SCRATCH_HOME"

echo "--- install.sh: full install into a scratch HOME ---"
SCRATCH_HOME=$(new_scratch_home)
out=$(run_install <<< "${REPO_ROOT}")
assert_status 0 "$?" "install.sh succeeds on a clean scratch HOME"
assert_file_exists "${SCRATCH_HOME}/.local/bin/gitscrnsvr" "installs gitscrnsvr"
assert_file_exists "${SCRATCH_HOME}/.config/systemd/user/gitscrnsvr.service" "installs the systemd unit"
assert_file_exists "${SCRATCH_HOME}/.config/gitscrnsvr/config.env" "writes config.env"

config="${SCRATCH_HOME}/.config/gitscrnsvr/config.env"
assert_contains "$(cat "$config")" "REPO_PATH:=${REPO_ROOT}" "config.env records the chosen repo path"
bash -n "$config"
assert_status 0 "$?" "config.env is valid shell"

echo "--- install.sh: re-running is idempotent ---"
echo "CUSTOM_MARKER=1" >> "$config"
out=$(run_install <<< "/some/other/path")
assert_contains "$out" "leaving it untouched" "re-running install.sh does not overwrite config.env"
assert_contains "$(cat "$config")" "CUSTOM_MARKER=1" "existing config.env content survives a re-install"

echo "--- uninstall.sh: removes installed files, keeps config by default ---"
out=$(run_uninstall <<< "n")
assert_status 0 "$?" "uninstall.sh exits 0"
assert_file_missing "${SCRATCH_HOME}/.local/bin/gitscrnsvr" "removes gitscrnsvr"
assert_file_missing "${SCRATCH_HOME}/.config/systemd/user/gitscrnsvr.service" "removes the systemd unit"
assert_file_exists "$config" "declining the prompt keeps config.env"

echo "--- uninstall.sh: --purge removes config too ---"
run_install <<< "${REPO_ROOT}" > /dev/null
run_uninstall --purge > /dev/null
assert_file_missing "${SCRATCH_HOME}/.config/gitscrnsvr" "--purge removes the whole config dir"

rm -rf "$SCRATCH_HOME" "$FAKE_SYSTEMCTL_DIR"

test_summary
