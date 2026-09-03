# EV-SP-019-20260824-TRANSPORT-TRACE-11

- **Evidence ID:** `EV-SP-019-20260824-TRANSPORT-TRACE-11`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T13:34:34Z and 2026-08-24T14:23:11Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`
- **Class:** Direct transport observation of the live process — not a policy assertion
- **Procedure:** `scripts/run-sp019-transport-probe.sh <pid> <seconds>` (new, read-only). It samples the kernel's own socket table for the exact PID with `lsof -nP -a -p <pid> -i`, so what it reports is what the process really had open. It opens no sockets of its own and records no remote peer addresses.

## Result

| Run | PID | Duration | Samples | Socket endpoints | Non-loopback peers | Verdict |
|-----|-----|----------|---------|------------------|--------------------|---------|
| 1 | 27211 | 300 s | 150 | 0 | 0 | no non-loopback egress observed |
| 2 | 38740 | 420 s | 210 | 0 | 0 | no non-loopback egress observed |

Run 2 covers the session in which the app wrote eight memory records through
the production turn path, so the observation spans actual memory activity
rather than an idle process.

Artifacts: `/tmp/aura-sp019-transport-probe.json` SHA-256
`cd9479a215568cb0158f4079c329fe6970d9fb045efe43063e7b511c42156e84`;
`/tmp/aura-sp019-transport-probe-run2.json` SHA-256
`5215ff350bc36b5a1b7d33fd00b553020018058acf742983440ffe62ece6f486`.

## Why this answers the gap

The previously recorded evidence was a **policy refusal** — the UI rejecting
`Allow remote context` while machine policy is local-only. That proves the
policy layer refuses, not that the transport layer stayed silent. This is the
missing half: with memory live and being written, the process held no IP
sockets at all, so no memory content could have left the machine regardless of
what any stored statement claimed.

## Falsifier

Any sampled socket whose remote half is outside `127.0.0.0/8`, `::1`, or
`localhost` would falsify the verdict; the probe exits non-zero and names the
offending ports if it sees one.

## Limitations

Sampling at a 2-second interval cannot exclude a sub-interval connection that
opened and closed entirely between two samples; it is an observation of the
socket table, not a packet capture. Loopback traffic (e.g. a local model
endpoint) would have been reported as allowed and none was observed either. No
remote addresses, payloads, or private data were recorded.
