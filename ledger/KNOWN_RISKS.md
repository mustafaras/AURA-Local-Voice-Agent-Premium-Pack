# Known Risks

| ID | Risk | Severity | Evidence | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
| R-001 | Continuous microphone access may undermine trust if state is unclear. | High | Product architecture | Persistent visual indicator, local processing, emergency stop, zero default retention. | Unassigned | Open |
| R-002 | UI automation may act on stale or incorrect targets. | High | Computer-use architecture | Freshness checks, target identity validation, atomic steps, confirmations. | Unassigned | Open |
| R-003 | Multiple local models may exceed 16 GB memory. | Medium | Target hardware | Resource scheduler, model unload, lightweight defaults, benchmarks. | Unassigned | Open |
