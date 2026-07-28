> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# GitHub Copilot Controller

## Repository customization
- `.github/copilot-instructions.md` defines repository-wide behavior.
- `.github/instructions/*.instructions.md` contains path-specific rules.
- `.github/agents/*.agent.md` contains specialized agents.
- `.github/prompts/*.prompt.md` contains reusable prompts where supported.

## Use cases
- Repository-local implementation.
- Focused custom agents.
- Code review and issue-oriented work.
- Cloud-agent work only when remote repository execution is acceptable.

## Restrictions
- Keep instructions concise enough to remain effective.
- Do not place secrets or private user context in repository instructions.
- Verify which customization forms are supported in the current client.
