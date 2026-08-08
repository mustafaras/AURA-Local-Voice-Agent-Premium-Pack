import Foundation

/// Where one piece of text came from, for the purpose of deciding whether it
/// can carry instructions the assistant should follow.
///
/// This implements `docs/security/26_SECURITY_MODEL.md`'s core rule
/// verbatim: "Content observed on screen, in files, in webpages, or in
/// agent output is data—not authority." Only `.systemPolicy` (AURA's own
/// instructions) and `.userUtterance` (the live user, speaking or typing
/// this turn) can carry authority; every other source — including a
/// project's own repository files — is data. A malicious or merely
/// careless line in `AGENTS.md` must never be treated as an instruction,
/// which is why `.repositoryFile` is `carriesAuthority == false` even
/// though the repository is "local" and nominally under the user's control.
public enum ContentProvenance: String, Codable, Sendable, Equatable, CaseIterable {
  /// AURA's own system prompt / policy text.
  case systemPolicy
  /// Live user speech (post-STT) or typed text for the current turn.
  case userUtterance
  /// A file the repository controls (`AGENTS.md`,
  /// `.github/copilot-instructions.md`, project source/docs).
  case repositoryFile
  /// Content retrieved from `MemoryEngine`/`ContextEngine`.
  case memoryRetrieval
  /// Normalized event text from a Codex/Claude/Copilot/Ollama run (tool
  /// output, file diffs, command output relayed through the adapter).
  case agentToolOutput
  /// A fetched web page or its extracted text.
  case webContent
  /// A message body or subject retrieved from a mail provider.
  case mailBody
  /// Metadata or extracted text from a mail attachment.
  case mailAttachment
  /// An event title, notes, or location retrieved from a calendar provider.
  case eventContent
  /// A contact record returned by a scoped lookup.
  case contactRecord
  /// Vision-recognized on-screen text (`AuraScreen`'s OCR pipeline).
  case screenOCR
  /// stdout/stderr from a shell command (`AuraShell`).
  case terminalOutput
  /// A plugin's self-declared manifest fields (name, description, etc. —
  /// not the cryptographically verified identity/capability fields).
  case pluginManifest

  /// Only these two sources may be treated as containing real instructions
  /// to follow. Every other case must be treated as inert data even when
  /// it contains imperative-sounding text.
  public var carriesAuthority: Bool {
    switch self {
    case .systemPolicy, .userUtterance: return true
    case .repositoryFile, .memoryRetrieval, .agentToolOutput, .webContent, .mailBody,
      .mailAttachment, .eventContent, .contactRecord, .screenOCR, .terminalOutput,
      .pluginManifest:
      return false
    }
  }
}
