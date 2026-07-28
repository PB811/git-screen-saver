#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

overall_status=0
for test_file in test_*.sh; do
    [[ "$test_file" == "test_helper.sh" ]] && continue
    echo "==> ${test_file}"
    bash "$test_file"
    status=$?
    [[ $status -ne 0 ]] && overall_status=1
    echo ""
done

exit $overall_status
