> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Wake Word and Speaker Authorization

## Pipeline
1. Local VAD gates analysis.
2. Wake-word model evaluates short windows.
3. Candidate detections pass debounce and confidence rules.
4. Optional speaker verification checks an enrolled local embedding.
5. A session activation event is emitted.

## Rules
- Wake word remains local.
- False accept and false reject metrics must be measured separately.
- Enrollment must include multiple acoustic conditions.
- Speaker verification is not sufficient authorization for high-risk actions.
- Support push-to-cancel and menu-bar emergency stop even though normal use is hands-free.
- Provide a privacy mode where only an explicit keyboard shortcut activates listening.

## Anti-trigger protections
- Suppress assistant-generated wake phrase.
- Require temporal consistency.
- Rate-limit repeated wake events.
- Ignore media playback where feasible.
