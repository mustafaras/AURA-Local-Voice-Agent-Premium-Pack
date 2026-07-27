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

## Implementation (Phase 19)

`ContentProvenance` (`Sources/AuraSecurity/ContentProvenance.swift`) labels every
piece of content by where it came from and whether it `carriesAuthority` —
implementing "Label every context item by provenance and trust" and "Keep
system policy outside retrieved content" as a type-level guarantee: only
`.systemPolicy` and `.userUtterance` ever carry authority, and every other
source (repository files, memory retrieval, agent tool output, web content,
screen OCR, terminal output, plugin manifests) is data, full stop — this is
"Never transfer authority from webpage or repository text" made structural,
not merely a convention to remember.

`PromptInjectionClassifier` (`Sources/AuraSecurity/PromptInjectionClassifier.swift`)
is the "dedicated security classifier plus deterministic rules": ~20
deterministic, weighted regex rules across instruction-override, role-hijack,
prompt-exfiltration, credential-exfiltration, unsanctioned-execution,
authority-bypass, hidden-instruction (zero-width characters, HTML comments),
data-exfiltration, and concealment-from-user categories, cumulative-severity
scored into `.clean`/`.suspicious`/`.blocked`. It only ever scans
non-authoritative content — authoritative content is never classified,
matching the provenance guarantee above rather than duplicating it.

`SecretScanner` (`Sources/AuraSecurity/SecretScanner.swift`) and the
consolidated `SecretPatternLibrary` (`Sources/AuraCore/SecretPatternLibrary.swift`)
provide the same "stop and explain when instructions conflict" spirit for
the credential-exfiltration case specifically: a single canonical secret-shape
list now backs `OutputRedactor.default`, `RepositoryInstructionsScanner`
(`AuraAgent`), and `SecretScanner`, so a new secret shape only needs adding
once and is caught everywhere.

**Adversarial tests:** `Tests/AuraSecurityTests/PromptInjectionClassifierTests.swift`
covers webpage-shaped, README/repository-file-shaped, terminal-output-shaped,
issue-text-shaped (via `.memoryRetrieval`), and OCR-text-shaped (`.screenOCR`)
adversarial content, plus hidden zero-width-character and HTML-comment
payloads, and proves authoritative content (`.userUtterance`/`.systemPolicy`)
is never scanned regardless of its phrasing.

**Known limitation:** the classifier is not yet wired into a live caller on
the screen-OCR, agent-tool-output-normalizer, or memory-retrieval paths — see
`docs/security/30_THREAT_MODEL.md` entries 3, 7, and 9. It is a complete,
tested, real component; the remaining work is integration into those
existing subsystems' real content flow, matching the same "not yet wired
into a real caller" pattern already documented for `ContextEngine`/
`MemoryEngine`/`ScreenContextEngine`/`ComputerUseControlLoop` (Phases 15–18).
