import SwiftUI

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
  static func statusColor(_ status: AuraAppStatus) -> Color {
    switch status {
    case .idle: return .green
    case .listening, .thinking, .speaking: return .accentColor
    case .starting: return .secondary
    case .restricted: return .orange
    case .stopped: return .secondary
    case .error: return .red
    }
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
        .font(.system(size: 12, weight: .semibold))
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
          .accessibilityLabel("Trace: \(traceSummary)")
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

  private var degradedNote: String { "Degraded response" }

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
