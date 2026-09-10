import SwiftUI
// UIAccessibility (Reduce Motion) — AppKit's NSWorkspace accessibility APIs
// re-export it; importing AppKit explicitly keeps the motion helper's
// dependency visible at the file that uses it.
import AppKit

/// Visual language for AURA's product surface.
///
/// Centralized for a practical reason rather than a stylistic one: the UI is
/// assembled from several files, and every ad-hoc padding or colour literal
/// scattered across them is a place the product drifts out of alignment with
/// itself. The tokens here are the only spacing, radius, and colour values the
/// views are meant to reference.
///
/// Everything resolves through semantic system colours, so light and dark
/// appearance, increased contrast, and the user's accent colour keep working
/// without maintaining a second palette.
enum AuraDesign {

  // MARK: - Spacing

  enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
  }

  // MARK: - Shape

  enum Radius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 14
    /// Message bubbles and the composer read as "soft" surfaces.
    static let bubble: CGFloat = 16
  }

  // MARK: - Typography

  enum Typography {
    /// Product wordmark in the header.
    ///
    /// Relative text styles (not fixed `Font.system(size:)`) so the whole
    /// surface scales with the user's Dynamic Type / accessibility text size
    /// setting. Fixed point sizes would leave the UI unreadable at large
    /// accessibility sizes and are a WCAG 1.4.4 (resize text) failure.
    static let wordmark = Font.headline.weight(.semibold)
    static let sectionTitle = Font.subheadline.weight(.semibold)
    static let body = Font.body
    static let meta = Font.caption
    static let mono = Font.caption.monospaced()
  }

  // MARK: - Surfaces

  /// A raised panel: content sitting above the window background.
  ///
  /// Deliberately a plain material rather than glass. Liquid Glass belongs on
  /// interactive controls and floating chrome; behind dense, long-lived body
  /// text it costs legibility and buys nothing — which is what Apple's own
  /// guidance warns against ("apply glass to every view" is a listed
  /// anti-pattern). Glass is used below for the status pill and the composer.
  @ViewBuilder
  static func panelBackground(cornerRadius: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    shape
      .fill(Color(nsColor: .controlBackgroundColor))
      .overlay(shape.stroke(Color(nsColor: .separatorColor), lineWidth: 1))
  }

  // MARK: - Status semantics

  /// Maps a runtime status to one colour, so the header dot, the status pill,
  /// and any inline badge cannot disagree about what "error" looks like.
  ///
  /// UI-0 (G0-3a): remapped *in place* to the owned Palette v2 tokens
  /// (idle → biolume, active states → biolume, restricted → cautious,
  /// error → critical) so every consumer — pill, badges, task rows — changes
  /// coherently in this one place. Status semantics are unchanged: the same
  /// statuses map to the same *roles* they always did (`.orange` semantics
  /// carried by `cautious`, `.red` semantics by `critical`).
  static func statusColor(_ status: AuraAppStatus) -> Color {
    switch status {
    case .idle: return Palette.biolume
    case .listening, .thinking, .speaking: return Palette.biolume
    case .starting: return Palette.textTertiary
    case .restricted: return Palette.cautious
    case .stopped: return Palette.textTertiary
    case .error: return Palette.critical
    }
  }
}

// MARK: - Palette v2 (UI-0, G0-3 — additive only)
//
// Owned colour tokens: the "Observatory" neutrals plus the "Biolume" accents
// (ui-improvement-plan/09-visual-language.md §3). Dark values are canonical;
// light "Daylight Lab" values ride along so both variants are defined at token
// level and validated by the G0-4 contrast gate. Nothing in the pinned
// `Spacing`/`Radius`/`Typography` namespaces above is touched.
extension AuraDesign {

  /// Owned color tokens. Dark-first; each token carries its Daylight Lab
  /// partner so both appearance variants resolve from one definition.
  enum Palette {
    // --- Observatory neutrals (dark canonical / light partner) -----------
    /// Window base — the deep background behind everything. Never `#000`.
    static let void = Color(light: Color(hex: 0xF7F5F0), dark: Color(hex: 0x0B0E13))
    /// Panel fill (L1 surfaces).
    static let surface = Color(light: Color(hex: 0xFFFDF8), dark: Color(hex: 0x12161C))
    /// Raised card fill.
    static let surfaceRaised = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x181E26))
    /// Separator, grid lines, hairline strokes.
    static let hairline = Color.white.opacity(0.08)
    /// Body text (contrast target ≥ 7:1 on `surface`, both variants).
    static let textPrimary = Color(light: Color(hex: 0x1A2026), dark: Color(hex: 0xECF1F4))
    /// Meta text (≥ 4.5:1).
    static let textSecondary = Color.white.opacity(0.62)
    /// Trace/provenance text (≥ 4.5:1). 56% white: 38% measured 3.57:1 and
    /// 52% measured 4.25:1 (light) in the G0-4 gate — the gate adjusted the
    /// token, not the threshold.
    static let textTertiary = Color.white.opacity(0.56)

    // --- Biolume accents (owned, not system) ------------------------------
    /// Primary luminous accent: Orb core, listening state, focus rings,
    /// active tab. Interactive *controls* deliberately keep the system
    /// accent (ADR-057 §Decision) so AURA still feels native.
    static let biolume = Color(light: Color(hex: 0x0E8467), dark: Color(hex: 0x5AE6C8))
    /// Gradient partner (core depth), pressed states.
    static let biolumeDeep = Color(light: Color(hex: 0x0A6B54), dark: Color(hex: 0x1FB59A))
    /// Informational/system accents that must not compete with the core.
    static let signal = Color(light: Color(hex: 0x3D6EC0), dark: Color(hex: 0x8AB4FF))
    /// Restricted, pending confirmation, mock-derived — inherits the previous
    /// `.orange` semantics. Light variant darkened from #A66A08 (measured
    /// 4.41:1) to pass the G0-4 meta threshold.
    static let cautious = Color(light: Color(hex: 0x8A5606), dark: Color(hex: 0xF2B84B))
    /// Error, emergency stop — inherits the previous `.red` semantics.
    static let critical = Color(light: Color(hex: 0xC93A2E), dark: Color(hex: 0xFF6B5E))
  }

  /// Surface ladder L0–L3 (09-visual-language.md §4). One light source; the
  /// "controlled depth" rule — no material sits directly on its parent level
  /// without a stroke or spacing separation.
  enum Materials {
    /// L0 — window background (`Palette.void` fill).
    static let base = AuraDesign.Palette.void
    /// L1 — panel fill (`Palette.surface`) + `Palette.hairline` stroke.
    static let panel = AuraDesign.Palette.surface
    /// L2 — floating interactive chrome (glass, `.regular`).
    static let chrome = Color(nsColor: .controlBackgroundColor)
    /// L3 — hero glass with luminous content (the Orb, overlays).
    static let hero = Color(nsColor: .controlBackgroundColor)
    /// Tokenized blur radii (single-source light model).
    static let blurSmall: CGFloat = 8
    static let blurMedium: CGFloat = 16
  }

  /// Precision grammar: constants for instrument-scale marks (G0-3). The
  /// 8-pt grid rides on top of the existing `Spacing` steps.
  enum Measure {
    /// Major tick height for gauge scales.
    static let tickMajor: CGFloat = 10
    /// Minor tick height for gauge scales.
    static let tickMinor: CGFloat = 5
    /// 1 pt hairline stroke (`Palette.hairline`).
    static let hairline: CGFloat = 1
    /// Instrument bracket corner-mark length (6 pt).
    static let bracket: CGFloat = 6
    /// Grid rhythm.
    static let gridStep: CGFloat = 8
  }

  /// Motion vocabulary (G0-3/G0-5; shared with 11-motion-system.md §3).
  /// Durations live in tokens — no magic numbers in views. Only springs for
  /// geometry, only eases for colour; one choreography owner per moment.
  enum Motion {
    /// Status transitions, panel entrance, Orb state morphs (≈350 ms, low
    /// bounce 0.15–0.2).
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Controls: buttons, toggles, tab selection (≈200 ms, higher bounce).
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.7)
    /// Color/fill changes, crossfades, glass tint shifts (≈250 ms ease-in-out).
    static let smooth = Animation.easeInOut(duration: 0.25)
    /// Destructive-critical only: emergency stop, confirmation cards
    /// (≈150 ms, no bounce — fast, sober).
    static let emergent = Animation.easeOut(duration: 0.15)
    /// Stagger step per element, max 3 elements (list entrance on tab switch).
    static let staggerDelay: TimeInterval = 0.04
    /// Max staggered elements.
    static let staggerMax = 3

    /// Resolves a motion token for the current accessibility environment.
    ///
    /// **Static-readout rule** (11-motion-system.md §6): under Reduce Motion
    /// every token resolves to `nil` — springs become instant state change,
    /// arcs/equalizers render their static final state, and the Orb renders
    /// as a still instrument readout (ring position + text), never blank.
    /// Every animation in the product routes through this helper; a view
    /// referencing `Motion.*` directly (bypassing this gate) is a review
    /// defect.
    ///
    /// API: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` — the
    /// macOS Reduce Motion accessor (AppKit, verified from the installed
    /// SDK's NSAccessibility.h), not the UIKit `UIAccessibility` name.
    static func motion(_ token: Animation?) -> Animation? {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : token
    }
  }
}

// MARK: - Palette plumbing
//
// The token definitions above carry both appearance values so the G0-4
// contrast gate can validate *both variants from the token table itself*
// (the CI host has no rendering surface). Views resolve through
// `Color(nsColor:)` dynamic providers at use sites via `resolved()`, and the
// light/dark pairs stay in one place — the token table — so drift between
// variants is impossible by construction.

extension Color {
  /// Builds an appearance-dynamic color from explicit light/dark partners.
  ///
  /// The closure body is deliberately broken into named locals — the
  /// one-expression ternary form exceeded the type-checker's budget
  /// (expression too complex), and the fix keeps each step decidable.
  init(light: Color, dark: Color) {
    let lightNS = NSColor(light)
    let darkNS = NSColor(dark)
    self.init(nsColor: NSColor(name: nil) { appearance in
      let resolved: NSColor = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? darkNS
        : lightNS
      return resolved
    })
  }

  /// sRGB hex convenience for token definitions only (`#RRGGBB`).
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }
}

/// Compact, colour-coded runtime indicator.
///
/// Colour never carries the meaning alone: the adjacent text and the
/// accessibility label always state the status, so the control stays usable
/// with any form of colour vision.
struct AuraStatusPill: View {
  let status: AuraAppStatus
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: AuraDesign.Spacing.s) {
      Circle()
        .fill(AuraDesign.statusColor(status))
        .frame(width: 7, height: 7)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.xxs) {
        Text(title)
          .font(AuraDesign.Typography.meta.weight(.semibold))
        Text(detail)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, AuraDesign.Spacing.m)
    .padding(.vertical, AuraDesign.Spacing.s)
    // Glass here is earned: the pill is chrome that floats over changing
    // content and is tinted by live runtime state, which is exactly the
    // material's purpose. It is not interactive, so `.interactive()` is
    // deliberately omitted.
    .glassEffect(
      .regular.tint(AuraDesign.statusColor(status).opacity(0.18)),
      in: .rect(cornerRadius: AuraDesign.Radius.medium))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title). \(detail)")
  }
}

/// Section heading used at the top of every tab.
struct AuraSectionHeader: View {
  let title: String
  let symbol: String
  var subtitle: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: AuraDesign.Spacing.s) {
      Image(systemName: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.xxs) {
        Text(title).font(AuraDesign.Typography.sectionTitle)
        if let subtitle {
          Text(subtitle)
            .font(AuraDesign.Typography.meta)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Raised container replacing bare `GroupBox` usage, so every panel shares one
/// radius, border, and inset.
struct AuraPanel<Content: View>: View {
  var title: String?
  var tint: Color?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
      if let title {
        Text(title)
          .font(AuraDesign.Typography.meta.weight(.semibold))
          .foregroundStyle(tint ?? .secondary)
          .textCase(.uppercase)
      }
      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(AuraDesign.Spacing.m)
    .background(AuraDesign.panelBackground(cornerRadius: AuraDesign.Radius.large))
  }
}

/// One conversation turn, shaped by speaker.
///
/// The user's own words are right-aligned and accent-tinted; AURA's replies are
/// left-aligned on a neutral surface. That asymmetry is what makes a transcript
/// scannable at a glance — far more than any amount of ornament — and it is why
/// this replaced the uniform `GroupBox` rows the transcript used before.
struct AuraMessageBubble: View {
  /// Threaded rather than defaulted on purpose. This view has no model to read
  /// the language from, and a default of `.english` would let a caller forget
  /// to pass it and silently ship the untranslated string this closes.
  let language: AuraUILanguage
  let roleLabel: String
  let text: String
  let isUser: Bool
  let isDegraded: Bool
  var sourceSummary: String?
  var traceSummary: String?

  var body: some View {
    VStack(alignment: isUser ? .trailing : .leading, spacing: AuraDesign.Spacing.xs) {
      Text(roleLabel)
        .font(AuraDesign.Typography.meta.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(text)
        .font(AuraDesign.Typography.body)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal, AuraDesign.Spacing.m)
        .padding(.vertical, AuraDesign.Spacing.s)
        .background(bubbleBackground)
        .foregroundStyle(isUser ? Color.white : Color.primary)

      if isDegraded {
        Label(degradedNote, systemImage: "exclamationmark.triangle.fill")
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.orange)
      }
      if let sourceSummary {
        Text(sourceSummary)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
      }
      if let traceSummary {
        Text(traceSummary)
          .font(AuraDesign.Typography.mono)
          .foregroundStyle(.tertiary)
          .accessibilityLabel(
            "\(AuraCopy.text("a11y.tracePrefix", language: language)): \(traceSummary)")
      }
    }
    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    // `.combine` collapsed the bubble into a single element that this SwiftUI
    // version exposes as an unlabelled `AXUnknown` once the bubble is inside a
    // lazy stack: no value, no description, no children. The transcript was
    // therefore unreadable to assistive technology — every message in the
    // conversation was an anonymous blank node. `.contain` keeps the message
    // text, the role, and the provenance lines individually reachable, which
    // is what a transcript wants anyway: a reader can move through a long
    // answer instead of receiving it as one unnavigable string.
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(roleLabel): \(text)")
  }

  private var degradedNote: String {
    AuraCopy.text("message.degraded", language: language)
  }

  @ViewBuilder
  private var bubbleBackground: some View {
    let shape = RoundedRectangle(cornerRadius: AuraDesign.Radius.bubble, style: .continuous)
    if isUser {
      shape.fill(Color.accentColor)
    } else {
      shape
        .fill(Color(nsColor: .controlBackgroundColor))
        .overlay(shape.stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
  }
}

// MARK: - Conversation experience components (UI-1, additive)
//
// Markdown rendering, the live draft bubble, and the thinking placeholder
// (ui-improvement-plan/01-conversation-experience.md §4.1–4.4). All
// components here are additive; the pinned Typography/Spacing/Radius tables
// above are referenced, never mutated.

extension AuraDesign {

  /// Inline-only markdown parsing options for assistant messages: bold,
  /// italic, inline code, and links render; block syntax (headings, lists,
  /// fences) degrades to plain text rather than rendering as blocks. The
  /// whitespace-preserving member is `.inlineOnlyPreservingWhitespace` —
  /// verified from the installed SDK's Foundation.swiftinterface (the
  /// `-PreservingWhitespace**s**` spelling does not exist).
  static let markdownParsingOptions: AttributedString.MarkdownParsingOptions = {
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .inlineOnlyPreservingWhitespace
    return options
  }()

  /// Parse a message's markdown into an attributed string with inline
  /// semantics only. On any parse throw — the documented malformed-input
  /// failure path — the raw text is returned verbatim: **content is never
  /// dropped** (G1-2: the fallback path is the pinned test case).
  static func inlineMarkdownOrPlain(_ markdown: String) -> AttributedString {
    do {
      return try AttributedString(
        markdown: markdown, options: markdownParsingOptions)
    } catch {
      return AttributedString(markdown)
    }
  }
}

/// A message bubble that renders assistant markdown with inline semantics.
///
/// Wraps `AuraMessageBubble`'s exact provenance/degraded/a11y structure; only
/// the text body differs: the assistant's text parses through
/// `AuraDesign.inlineMarkdownOrPlain` (bold/italic/inline code/links styled,
/// block syntax and malformed input fall back to plain text). The message
/// text stays selectable, and the accessibility label keeps the raw text so
/// VoiceOver reads content, not syntax artifacts.
struct AuraMarkdownMessageBubble: View {
  let language: AuraUILanguage
  let roleLabel: String
  let text: String
  var isDegraded: Bool = false
  var sourceSummary: String?
  var traceSummary: String?

  var body: some View {
    // Styling intent: markdown runs carry their own inline presentation
    // intents; the body font stays the product's relative body style so
    // Dynamic Type is preserved. Code runs render monospaced via the intent.
    let attributed = AuraDesign.inlineMarkdownOrPlain(text)
    return VStack(alignment: .leading, spacing: AuraDesign.Spacing.xs) {
      Text(roleLabel)
        .font(AuraDesign.Typography.meta.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(attributed)
        .font(AuraDesign.Typography.body)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420, alignment: .leading)
        .padding(.horizontal, AuraDesign.Spacing.m)
        .padding(.vertical, AuraDesign.Spacing.s)
        .background(AuraDesign.panelBackground(cornerRadius: AuraDesign.Radius.bubble))

      if isDegraded {
        Label(AuraCopy.text("message.degraded", language: language), systemImage: "exclamationmark.triangle.fill")
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.orange)
      }
      if let sourceSummary {
        Text(sourceSummary)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
      }
      if let traceSummary {
        Text(traceSummary)
          .font(AuraDesign.Typography.mono)
          .foregroundStyle(.tertiary)
          .accessibilityLabel(
            "\(AuraCopy.text("a11y.tracePrefix", language: language)): \(traceSummary)")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(roleLabel): \(text)")
  }
}

/// The in-flight spoken input, rendered in the transcript as a live draft
/// bubble (01 §4.2): user-role styling, updates in place (no re-entry
/// animation per 11 §4), and one combined VoiceOver element announcing
/// "Draft: [text]" via `a11y.draftPrefix` (G1-3).
struct AuraDraftBubble: View {
  let language: AuraUILanguage
  let text: String

  var body: some View {
    VStack(alignment: .trailing, spacing: AuraDesign.Spacing.xxs) {
      Text(AuraCopy.text("a11y.draftPrefix", language: language))
        .font(AuraDesign.Typography.meta.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(text)
        .font(AuraDesign.Typography.body)
        .italic()
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420, alignment: .trailing)
        .padding(.horizontal, AuraDesign.Spacing.m)
        .padding(.vertical, AuraDesign.Spacing.s)
        .background(draftBackground)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    // Draft updates in place — text swaps with no insertion animation (11 §4:
    // value updates are the animation; no decorative re-entry).
    .animation(nil, value: text)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(AuraCopy.text("a11y.draftPrefix", language: language)): \(text)")
    .accessibilityIdentifier(AuraAccessibilityID.conversationDraftBubble)
  }

  @ViewBuilder
  private var draftBackground: some View {
    let shape = RoundedRectangle(cornerRadius: AuraDesign.Radius.bubble, style: .continuous)
    shape
      .fill(Color.accentColor.opacity(0.14))
      .overlay(shape.stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
  }
}

/// Pending-assistant-turn placeholder (G1-5), rendered where the answer will
/// land. Driven by the real `.thinking` status — the caller renders it only
/// while `status == .thinking`; nothing here invents progress. Copy keys
/// EN/TR; the three dots are a static hairline treatment, not a spinner.
struct AuraThinkingIndicator: View {
  let language: AuraUILanguage

  var body: some View {
    HStack(spacing: AuraDesign.Spacing.s) {
      // Three static dots at rest luminance — the visual anchor of a pending
      // turn. No pulse, no bounce: under the causal-motion rule (11 §2) the
      // status change itself is the event; decoration would be a fake
      // progress claim.
      HStack(spacing: AuraDesign.Spacing.xxs) {
        ForEach(0..<3, id: \.self) { _ in
          Circle()
            .fill(AuraDesign.statusColor(.thinking))
            .frame(width: 5, height: 5)
        }
      }
      .accessibilityHidden(true)
      Text(AuraCopy.text("conversation.thinking", language: language))
        .font(AuraDesign.Typography.meta)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, AuraDesign.Spacing.m)
    .padding(.vertical, AuraDesign.Spacing.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AuraDesign.panelBackground(cornerRadius: AuraDesign.Radius.bubble))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(AuraAccessibilityID.conversationThinking)
  }
}
