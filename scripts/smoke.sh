#!/usr/bin/env bash
# Smoke test: the public URL must answer, and /version must be the commit we just deployed.
# If ECS's circuit breaker rolled a bad release back, the old version answers and this fails, which is what we want.
#   scripts/smoke.sh <base-url> <expected-version>
set -euo pipefail
url="${1:?usage: smoke.sh <base-url> <expected-version>}"
expected="${2:?usage: smoke.sh <base-url> <expected-version>}"
for _ in $(seq 1 30); do
  if body=$(curl -sf --max-time 5 "$url/version"); then
    echo "service answered: $body"
    case "$body" in
      *"\"$expected\""*) echo "OK: running version matches $expected"; exit 0 ;;
      *) echo "FAIL: expected version $expected (a failed release may have been rolled back)"; exit 1 ;;
    esac
  fi
  sleep 5
done
echo "FAIL: $url never answered"; exit 1
