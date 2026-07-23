> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Plugin and Adapter System

## Plugin manifest
- ID and semantic version
- vendor and signature
- capabilities
- schemas
- required permissions
- supported application bundle IDs
- network domains
- executable dependencies
- migration requirements
- audit level

## Security
- Plugins are untrusted until explicitly installed and approved.
- Validate signatures and hashes.
- Run with the minimum possible process and filesystem permissions.
- No dynamic code download without user action.
- Provide disable, quarantine, and uninstall workflows.
