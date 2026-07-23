> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Terminal and Shell Execution

## Principle
Use typed commands, not free-form shell concatenation.

## Command object
- executable
- argument array
- working directory
- environment allowlist
- timeout
- expected exit codes
- risk classification
- sandbox mode
- output redaction rules

## Prohibitions
- `shell=true` by default
- hidden privilege escalation
- broad glob deletion
- unbounded recursive operations
- piping secrets
- execution copied from untrusted screen content
- command substitution assembled from model text

## Verification
Capture exit status, bounded stdout/stderr, duration, resource use where available, and changed-files evidence.
