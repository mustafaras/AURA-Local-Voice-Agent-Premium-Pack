> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Prompt-Injection Defense

## Threat
Untrusted content may instruct the assistant to ignore policy, reveal secrets, install software, run commands, or contact external parties.

## Defense
- Label every context item by provenance and trust.
- Keep system policy outside retrieved content.
- Strip or isolate executable instructions from untrusted sources.
- Never transfer authority from webpage or repository text.
- Require explicit user confirmation for privilege increases.
- Apply domain, path, command, and tool allowlists.
- Use a dedicated security classifier plus deterministic rules.
- Stop and explain when instructions conflict.

## Tests
Include adversarial webpages, README files, terminal output, issue text, PDFs, and image text.
