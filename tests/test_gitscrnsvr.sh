#!/usr/bin/env bash
# Regression tests for the pure parsing logic and CLI surface in
# ../gitscrnsvr. Run directly or via run_all.sh.

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

GITSCRNSVR="${REPO_ROOT}/gitscrnsvr"
SCRATCH_HOME=$(new_scratch_home)
trap 'rm -rf "$SCRATCH_HOME"' EXIT

# Source in isolation: a scratch HOME with no XDG overrides means no real
# user config.env leaks into these tests, and no ~/.local/bin/gitlogue etc.
# from the actual machine gets picked up by find_gitlogue.
HOME="$SCRATCH_HOME"
export HOME
unset XDG_CONFIG_HOME XDG_RUNTIME_DIR GITLOGUE
source "$GITSCRNSVR"
set +e +u   # this script's own assertions should survive a failing check

echo "--- parse_idle_reply ---"
assert_eq "12345" "$(parse_idle_reply '(uint64 12345,)')" "parses a normal idle reply"
assert_eq "0" "$(parse_idle_reply '(uint64 0,)')" "parses a zero idle reply"

echo "--- parse_lock_reply ---"
assert_eq "true" "$(parse_lock_reply '(true,)')" "true reply parses as true"
assert_eq "false" "$(parse_lock_reply '(false,)')" "false reply parses as false"

echo "--- newer_version ---"
assert_eq "0.2.0" "$(newer_version 0.1.0 0.2.0)" "0.2.0 is newer than 0.1.0"
assert_eq "1.0.0" "$(newer_version 1.0.0 0.9.9)" "1.0.0 is newer than 0.9.9"
assert_eq "1.2.3" "$(newer_version 1.2.3 1.2.3)" "equal versions return either side"

echo "--- parse_release_tag ---"
json='{"tag_name": "v1.4.0", "name": "release"}'
assert_eq "1.4.0" "$(parse_release_tag "$json")" "strips leading v from tag_name"
assert_eq "" "$(parse_release_tag '{"name": "no tag here"}')" "missing tag_name yields empty"

echo "--- find_gitlogue ---"

# Each case below isolates HOME/PATH/GITLOGUE via a command-substitution
# subshell (to capture find_gitlogue's stdout), but every assert_* call
# itself runs in this script's own shell so PASS_COUNT/FAIL_COUNT persist.

unset GITLOGUE
result=$(GITLOGUE=/custom/path/to/gitlogue find_gitlogue)
assert_eq "/custom/path/to/gitlogue" "$result" "explicit GITLOGUE override wins"

fake_bin=$(mktemp -d)
printf '#!/bin/sh\n' > "${fake_bin}/gitlogue"
chmod +x "${fake_bin}/gitlogue"
unset GITLOGUE
result=$(PATH="${fake_bin}:${PATH}" find_gitlogue)
assert_eq "${fake_bin}/gitlogue" "$result" "found via PATH"
rm -rf "$fake_bin"

fake_home=$(mktemp -d)
mkdir -p "${fake_home}/.cargo/bin"
printf '#!/bin/sh\n' > "${fake_home}/.cargo/bin/gitlogue"
chmod +x "${fake_home}/.cargo/bin/gitlogue"
unset GITLOGUE
result=$(HOME="$fake_home" PATH=/usr/bin:/bin find_gitlogue)
assert_eq "${fake_home}/.cargo/bin/gitlogue" "$result" "found via candidate list when absent from PATH"
rm -rf "$fake_home"

# Skip on machines that already have gitlogue at one of the fixed system
# candidate paths (e.g. a dev box with Homebrew/Linuxbrew installed) since
# find_gitlogue is correctly expected to find it there; only assert "not
# found" where none of those paths actually exist, as is the case in CI.
system_candidate_present=false
for path in /opt/homebrew/bin/gitlogue /home/linuxbrew/.linuxbrew/bin/gitlogue \
            /usr/local/bin/gitlogue /usr/bin/gitlogue; do
    [[ -x "$path" ]] && system_candidate_present=true
done

fake_home=$(mktemp -d)
unset GITLOGUE
if $system_candidate_present; then
    echo "skip - find_gitlogue \"not found\" case (this machine has a real gitlogue at a system path)"
elif HOME="$fake_home" PATH=/usr/bin:/bin find_gitlogue >/dev/null 2>&1; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "not ok - find_gitlogue should fail when gitlogue is nowhere to be found"
else
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "ok - find_gitlogue fails when gitlogue is nowhere to be found"
fi
rm -rf "$fake_home"

echo "--- CLI surface (subprocess, so main() actually runs) ---"

run_cli() {
    env -u XDG_CONFIG_HOME -u XDG_RUNTIME_DIR -u GITLOGUE HOME="$SCRATCH_HOME" "$GITSCRNSVR" "$@" 2>&1
}

out=$(run_cli --version); assert_eq "gitscrnsvr 0.1.0" "$out" "--version prints version"
out=$(run_cli version); assert_eq "gitscrnsvr 0.1.0" "$out" "bare 'version' prints version"
out=$(run_cli -V); assert_eq "gitscrnsvr 0.1.0" "$out" "-V prints version"

out=$(run_cli --help); assert_contains "$out" "Usage: gitscrnsvr" "--help shows usage"
out=$(run_cli help); assert_contains "$out" "Usage: gitscrnsvr" "bare 'help' shows usage"

run_cli --bogus-flag >/dev/null 2>&1
assert_status 1 "$?" "unknown flag exits 1"

test_summary
