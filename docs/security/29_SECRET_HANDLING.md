> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Secret Handling

- Store credentials in macOS Keychain or backend-native secure stores.
- Pass secrets through narrowly scoped environment injection.
- Redact known patterns and registered secret values from logs.
- Never read `.env`, SSH keys, browser stores, or password managers unless the task explicitly requires and permits it.
- Never include secrets in model prompts when a local token exchange or broker can perform the action.
- Rotate and revoke after suspected exposure.
