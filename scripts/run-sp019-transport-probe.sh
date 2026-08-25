#!/bin/zsh
set -euo pipefail

# SP-019 transport probe: observe a live AURA process's actual network sockets
# while the user drives the memory controls.
#
# The point is not "the code says local-only" — a policy assertion is not a
# transport observation. This samples the kernel's own socket table for the
# exact PID, so what it reports is what the process really had open.
#
# It is read-only: it opens no sockets of its own, mutates nothing, and never
# writes captured addresses of remote peers into the repository. The caller is
# expected to fold the summary (not the raw sample) into an evidence file.
#
# Usage:  scripts/run-sp019-transport-probe.sh <pid> [seconds] [output-path]

PID="${1:?usage: run-sp019-transport-probe.sh <pid> [seconds] [output-path]}"
DURATION="${2:-60}"
OUTPUT="${3:-/tmp/aura-sp019-transport-probe.json}"
INTERVAL="${SP019_PROBE_INTERVAL:-2}"

if ! /bin/ps -p "$PID" > /dev/null 2>&1; then
  echo "error: no live process with pid $PID" >&2
  exit 1
fi

echo "==> Sampling network sockets for pid $PID every ${INTERVAL}s for ${DURATION}s"

SAMPLE_DIR="$(mktemp -d)"
trap 'rm -rf "$SAMPLE_DIR"' EXIT
SAMPLES=0
ELAPSED=0

while (( ELAPSED < DURATION )); do
  if ! /bin/ps -p "$PID" > /dev/null 2>&1; then
    echo "==> process exited after ${ELAPSED}s; stopping"
    break
  fi
  # -i lists IP sockets only; -nP keeps numeric hosts/ports so nothing is
  # resolved over the network by the probe itself.
  /usr/sbin/lsof -nP -a -p "$PID" -i >> "$SAMPLE_DIR/raw.txt" 2>/dev/null || true
  SAMPLES=$(( SAMPLES + 1 ))
  ELAPSED=$(( ELAPSED + INTERVAL ))
  sleep "$INTERVAL"
done

touch "$SAMPLE_DIR/raw.txt"

# Every socket endpoint seen, excluding lsof's header line.
ENDPOINTS="$(awk 'NR>0 && $1 != "COMMAND" { for (i = 1; i <= NF; i++) if ($i ~ /->/ || $i ~ /:[0-9]+$/) print $i }' \
  "$SAMPLE_DIR/raw.txt" | sort -u || true)"

# A peer address is non-loopback when the remote half of `local->remote` is
# not 127.0.0.0/8, ::1, or localhost. Listening sockets have no remote half.
NON_LOOPBACK="$(printf '%s\n' "$ENDPOINTS" | grep -F -- '->' \
  | awk -F'->' '{ print $2 }' \
  | grep -v -E '^(127\.[0-9]+\.[0-9]+\.[0-9]+|\[?::1\]?|localhost):' || true)"

TOTAL_ENDPOINTS="$(printf '%s\n' "$ENDPOINTS" | grep -c . || true)"
NON_LOOPBACK_COUNT="$(printf '%s\n' "$NON_LOOPBACK" | grep -c . || true)"

/usr/bin/python3 - "$OUTPUT" "$PID" "$SAMPLES" "$TOTAL_ENDPOINTS" "$NON_LOOPBACK_COUNT" <<'PY'
import json, sys, datetime
output, pid, samples, endpoints, non_loopback = sys.argv[1:6]
json.dump({
    "probe": "SP-019 transport",
    "generatedAt": datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "pid": int(pid),
    "samples": int(samples),
    "socketEndpointsObserved": int(endpoints),
    "nonLoopbackPeers": int(non_loopback),
    # The verdict is the whole point: a live process with zero non-loopback
    # peers is a transport observation, not a policy claim.
    "verdict": "no non-loopback egress observed" if int(non_loopback) == 0
        else "NON-LOOPBACK EGRESS OBSERVED",
}, open(output, "w"), indent=2, sort_keys=True)
print("wrote", output)
PY

echo "==> samples=$SAMPLES endpoints=$TOTAL_ENDPOINTS non_loopback=$NON_LOOPBACK_COUNT"
if [[ "$NON_LOOPBACK_COUNT" != "0" ]]; then
  echo "==> non-loopback peers observed (ports only shown):" >&2
  printf '%s\n' "$NON_LOOPBACK" | awk -F: '{ print "    port " $NF }' | sort -u >&2
  exit 2
fi
echo "==> no non-loopback egress observed"
