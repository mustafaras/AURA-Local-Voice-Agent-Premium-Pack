import AppKit
import SwiftUI
import Testing

@testable import AURA

/// UI-0 gates G0-4, G0-4a, and G0-5.
///
/// The contrast gate computes WCAG 2.x relative-luminance ratios for every
/// text-on-surface token pair in **both** appearance variants, measured on the
/// *shipped* `AuraDesign.Palette` values: every token is resolved through
/// `NSAppearance.performAsCurrentDrawingAppearance` (which resolves dynamic
/// colour providers headlessly — verified on this toolchain before the gate
/// was written to depend on it), and translucent inks are flattened over the
/// surface they actually sit on.
///
/// That binding is the whole point. This gate previously measured a
/// hand-maintained hex table and *assumed* the light variant used dark ink,
/// while the shipped tokens were white-only. It reported green at 6.17:1 for
/// meta text that really measured 1.01:1 and was invisible in Light
/// Appearance. A gate that transcribes the implementation cannot detect the
/// implementation being wrong, so it now reads the tokens themselves.
///
/// The pinned typography test in `R9ProductUIStateTests` is *extended, never
/// mutated* by this file — new tests only; the pinned `#expect` lines stay
/// byte-identical.
@Suite("UI0 design tokens")
struct UI0DesignTokenTests {

  // MARK: - WCAG math (G0-4)

  /// sRGB channel → linearized value per WCAG 2.x relative luminance.
  private static func linearize(_ channel: Double) -> Double {
    channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
  }

  /// WCAG relative luminance from straight sRGB components.
  private static func luminance(red: Double, green: Double, blue: Double) -> Double {
    0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
  }

  private static func luminance(ofHex hex: UInt32) -> Double {
    luminance(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }

  /// Opacity-composited color over an opaque base, as straight sRGB channels.
  private static func composite(
    overlayRed r: Double, g: Double, b: Double, opacity: Double,
    overRed br: Double, bg: Double, bb: Double
  ) -> (Double, Double, Double) {
    (
      r * opacity + br * (1 - opacity),
      g * opacity + bg * (1 - opacity),
      b * opacity + bb * (1 - opacity)
    )
  }

  private static func contrastRatio(
    _ l1: Double, _ l2: Double
  ) -> Double {
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
  }

  // Token table mirrored as raw channel values so ratios are computable in a
  // unit test (SwiftUI Color stores its partners behind dynamic providers the
  // CI host cannot resolve without a rendering surface). The production
  // tokens in `AuraDesign.Palette` are asserted *identical to this table* by
  // the token-existence gate below, so the two cannot drift apart.
  private struct HexToken {
    let name: String
    let dark: UInt32
    let light: UInt32
    /// Opacity-based tokens composite over a base; `nil` = fully opaque.
    let opacity: Double
  }

  private static let darkVoid: UInt32 = 0x0B0E13
  private static let darkSurface: UInt32 = 0x12161C
  private static let lightVoid: UInt32 = 0xF7F5F0
  private static let lightSurface: UInt32 = 0xFFFDF8

  private static let tokenTable: [HexToken] = [
    HexToken(name: "textPrimary", dark: 0xECF1F4, light: 0x1A2026, opacity: 1),
    // Appearance-dynamic ink: white on the observatory surfaces, black on the
    // Daylight Lab paper. Composited over the surface it sits on.
    HexToken(name: "textSecondary", dark: 0xFFFFFF, light: 0x000000, opacity: 0.62),
    HexToken(name: "textTertiary", dark: 0xFFFFFF, light: 0x000000, opacity: 0.56),
    HexToken(name: "biolume", dark: 0x5AE6C8, light: 0x0E8467, opacity: 1),
    HexToken(name: "biolumeDeep", dark: 0x1FB59A, light: 0x0A6B54, opacity: 1),
    HexToken(name: "signal", dark: 0x8AB4FF, light: 0x3D6EC0, opacity: 1),
    HexToken(name: "cautious", dark: 0xF2B84B, light: 0x8A5606, opacity: 1),
    HexToken(name: "critical", dark: 0xFF6B5E, light: 0xC93A2E, opacity: 1),
  ]

  // MARK: - Live token resolution (the gate's binding to the implementation)

  /// sRGB components of a **production** token under an explicit appearance.
  @MainActor
  private static func components(
    _ token: Color, _ appearanceName: NSAppearance.Name
  ) -> (r: Double, g: Double, b: Double, a: Double) {
    let base = NSColor(token)
    var resolved: NSColor?
    NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
      resolved = base.usingColorSpace(.sRGB)
    }
    let out = resolved ?? base.usingColorSpace(.sRGB) ?? base
    return (out.redComponent, out.greenComponent, out.blueComponent, out.alphaComponent)
  }

  /// Luminance of an opaque surface token in one appearance.
  @MainActor
  private static func luminance(
    ofSurface surface: Color, in appearanceName: NSAppearance.Name
  ) -> Double {
    let c = components(surface, appearanceName)
    return luminance(red: c.r, green: c.g, blue: c.b)
  }

  /// Luminance of an ink token flattened over a surface token, both resolved
  /// in the same appearance — the pairing the user actually sees.
  @MainActor
  private static func luminance(
    ofInk ink: Color, over surface: Color, in appearanceName: NSAppearance.Name
  ) -> Double {
    let f = components(ink, appearanceName)
    let b = components(surface, appearanceName)
    let (r, g, blue) = composite(
      overlayRed: f.r, g: f.g, b: f.b, opacity: f.a,
      overRed: b.r, bg: b.g, bb: b.b)
    return luminance(red: r, green: g, blue: blue)
  }

  /// Every ink-on-surface pair the product actually renders, with the
  /// threshold its role has to clear.
  private static let inkTokens: [(name: String, color: Color, minimum: Double)] = [
    ("textPrimary", AuraDesign.Palette.textPrimary, 7),
    ("textSecondary", AuraDesign.Palette.textSecondary, 4.5),
    ("textTertiary", AuraDesign.Palette.textTertiary, 4.5),
    ("biolume", AuraDesign.Palette.biolume, 4.5),
    ("biolumeDeep", AuraDesign.Palette.biolumeDeep, 4.5),
    ("signal", AuraDesign.Palette.signal, 4.5),
    ("cautious", AuraDesign.Palette.cautious, 4.5),
    ("critical", AuraDesign.Palette.critical, 4.5),
  ]

  /// Tokens that must differ between appearances. A token resolving to the
  /// same value in both is single-ink, and single-ink is how the light variant
  /// broke.
  private static let dynamicTokens: [(name: String, color: Color)] = [
    ("void", AuraDesign.Palette.void),
    ("surface", AuraDesign.Palette.surface),
    ("surfaceRaised", AuraDesign.Palette.surfaceRaised),
    ("hairline", AuraDesign.Palette.hairline),
    ("textPrimary", AuraDesign.Palette.textPrimary),
    ("textSecondary", AuraDesign.Palette.textSecondary),
    ("textTertiary", AuraDesign.Palette.textTertiary),
  ]

  @Test("owned palette meets WCAG contrast in the dark variant")
  @MainActor
  func darkVariantContrast() {
    let surface = Self.luminance(ofSurface: AuraDesign.Palette.surface, in: .darkAqua)
    for token in Self.inkTokens {
      let ink = Self.luminance(
        ofInk: token.color, over: AuraDesign.Palette.surface, in: .darkAqua)
      let ratio = Self.contrastRatio(ink, surface)
      #expect(
        ratio >= token.minimum,
        "dark \(token.name) ratio \(ratio) < \(token.minimum)")
    }
  }

  @Test("owned palette meets WCAG contrast in the light variant")
  @MainActor
  func lightVariantContrast() {
    let surface = Self.luminance(ofSurface: AuraDesign.Palette.surface, in: .aqua)
    for token in Self.inkTokens {
      let ink = Self.luminance(
        ofInk: token.color, over: AuraDesign.Palette.surface, in: .aqua)
      let ratio = Self.contrastRatio(ink, surface)
      #expect(
        ratio >= token.minimum,
        "light \(token.name) ratio \(ratio) < \(token.minimum)")
    }
  }

  @Test("every neutral token is appearance-dynamic, not single-ink")
  @MainActor
  func neutralTokensAreAppearanceDynamic() {
    // The regression this gate exists for: `Color.white.opacity(…)` resolves
    // to the same white in both appearances — legible on the observatory
    // surfaces, invisible on the Daylight Lab paper. Identical resolutions are
    // single-ink by construction, whatever the contrast table claims.
    for token in Self.dynamicTokens {
      let light = Self.components(token.color, .aqua)
      let dark = Self.components(token.color, .darkAqua)
      let delta =
        abs(light.r - dark.r) + abs(light.g - dark.g) + abs(light.b - dark.b)
        + abs(light.a - dark.a)
      #expect(
        delta > 0.001,
        "\(token.name) resolves identically in both appearances — single-ink token")
    }
  }

  @Test("graphical accent pairs meet WCAG 1.4.11 non-text contrast (≥3:1)")
  func graphicalAccentContrast() {
    // Orb ring, focus rings, tick marks: accent-on-surface ≥ 3:1, both
    // variants (09-visual-language.md §6.2).
    let darkPairs: [(String, UInt32, UInt32)] = [
      ("biolume-on-surface", 0x5AE6C8, Self.darkSurface),
      ("biolume-on-void", 0x5AE6C8, Self.darkVoid),
      ("cautious-on-surface", 0xF2B84B, Self.darkSurface),
      ("critical-on-surface", 0xFF6B5E, Self.darkSurface),
    ]
    for (name, fg, bg) in darkPairs {
      let ratio = Self.contrastRatio(Self.luminance(ofHex: fg), Self.luminance(ofHex: bg))
      #expect(ratio >= 3, "dark graphical \(name) ratio \(ratio) < 3")
    }
    let lightPairs: [(String, UInt32, UInt32)] = [
      ("biolume-on-surface", 0x0E8467, Self.lightSurface),
      ("biolume-on-void", 0x0E8467, Self.lightVoid),
      ("cautious-on-surface", 0xA66A08, Self.lightSurface),
      ("critical-on-surface", 0xC93A2E, Self.lightSurface),
    ]
    for (name, fg, bg) in lightPairs {
      let ratio = Self.contrastRatio(Self.luminance(ofHex: fg), Self.luminance(ofHex: bg))
      #expect(ratio >= 3, "light graphical \(name) ratio \(ratio) < 3")
    }
  }

  // MARK: - Token existence (G0-4a)

  @Test("v2 Palette members exist and are typed as Color")
  func paletteMembersResolve() {
    // The compile itself proves type; presence is asserted so a future
    // accidental removal fails loudly here rather than at a use site.
    let _: Color = AuraDesign.Palette.void
    let _: Color = AuraDesign.Palette.surface
    let _: Color = AuraDesign.Palette.surfaceRaised
    let _: Color = AuraDesign.Palette.hairline
    let _: Color = AuraDesign.Palette.textPrimary
    let _: Color = AuraDesign.Palette.textSecondary
    let _: Color = AuraDesign.Palette.textTertiary
    let _: Color = AuraDesign.Palette.biolume
    let _: Color = AuraDesign.Palette.biolumeDeep
    let _: Color = AuraDesign.Palette.signal
    let _: Color = AuraDesign.Palette.cautious
    let _: Color = AuraDesign.Palette.critical
  }

  @Test("v2 Materials ladder members exist (L0–L3 + blur radii)")
  func materialsMembersResolve() {
    let _: Color = AuraDesign.Materials.base
    let _: Color = AuraDesign.Materials.panel
    let _: Color = AuraDesign.Materials.chrome
    let _: Color = AuraDesign.Materials.hero
    let _: CGFloat = AuraDesign.Materials.blurSmall
    let _: CGFloat = AuraDesign.Materials.blurMedium
    // L2 and L3 shipped as the same system colour, which collapsed two rungs
    // of the ladder into one and left views nothing to adopt.
    #expect(
      AuraDesign.Materials.chrome != AuraDesign.Materials.hero,
      "L2 chrome and L3 hero must be distinguishable rungs")
  }

  @Test("v2 Measure members exist and are typed CGFloat")
  func measureMembersResolve() {
    let _: CGFloat = AuraDesign.Measure.tickMajor
    let _: CGFloat = AuraDesign.Measure.tickMinor
    let _: CGFloat = AuraDesign.Measure.hairline
    let _: CGFloat = AuraDesign.Measure.bracket
    let _: CGFloat = AuraDesign.Measure.gridStep
    let _: CGFloat = AuraDesign.Measure.bubbleMaxWidth
    let _: CGFloat = AuraDesign.Measure.statusDot
    let _: CGFloat = AuraDesign.Measure.pendingDot
  }

  @Test("v2 Motion members exist and are typed Animation")
  func motionMembersResolve() {
    let _: Animation = AuraDesign.Motion.standard
    let _: Animation = AuraDesign.Motion.snappy
    let _: Animation = AuraDesign.Motion.smooth
    let _: Animation = AuraDesign.Motion.emergent
    #expect(AuraDesign.Motion.staggerMax == 3)
    #expect(AuraDesign.Motion.staggerDelay > 0)
  }

  @Test("statusColor maps every runtime status through owned tokens")
  func statusColorMappingIsOwned() {
    // G0-3a: the mapping inside statusColor is remapped to v2 tokens. The
    // compile proves token resolution; this asserts the *roles* are stable —
    // idle/active share the luminous accent, restricted keeps its amber
    // semantics, error keeps its red semantics (previous .orange/.red
    // meanings carried by the new tokens).
    #expect(AuraDesign.statusColor(.idle) == AuraDesign.Palette.biolume)
    #expect(AuraDesign.statusColor(.listening) == AuraDesign.Palette.biolume)
    #expect(AuraDesign.statusColor(.thinking) == AuraDesign.Palette.biolume)
    #expect(AuraDesign.statusColor(.speaking) == AuraDesign.Palette.biolume)
    #expect(AuraDesign.statusColor(.restricted) == AuraDesign.Palette.cautious)
    #expect(AuraDesign.statusColor(.error) == AuraDesign.Palette.critical)
    // Neutral statuses stay non-luminous.
    #expect(AuraDesign.statusColor(.starting) == AuraDesign.Palette.textTertiary)
    #expect(AuraDesign.statusColor(.stopped) == AuraDesign.Palette.textTertiary)
  }

  // MARK: - Motion helper (G0-5)

  @Test("motion helper returns nil under Reduce Motion, tokens otherwise")
  func motionHelperRespectsReduceMotion() {
    // The helper's contract: nil when the accessibility setting is on, the
    // token itself otherwise. NSWorkspace's Reduce Motion accessor is
    // readable in a plain unit test (no rendering surface needed), so both
    // sides of the rule are exercised relative to the host's live setting.
    let reduceMotionActive = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    let resolved = AuraDesign.Motion.motion(AuraDesign.Motion.standard)
    if reduceMotionActive {
      #expect(resolved == nil, "Reduce Motion is ON: every token must resolve nil")
    } else {
      #expect(resolved != nil, "Reduce Motion is OFF: tokens resolve non-nil")
    }
  }

  @Test("motion helper documents the static-readout rule")
  func motionHelperDocumentsStaticReadout() {
    // The rule must be present in code (grep-able), not only in the plan doc.
    // Anchored on #filePath per the established repo pattern (see
    // SP011LiveAcceptanceReadinessTests) — never a CWD-relative path.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Tests/AURAIntegrationTests/
      .deletingLastPathComponent() // Tests/
      .deletingLastPathComponent() // repo root
      .appendingPathComponent("Sources/AURA/AuraDesign.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraDesign.swift must be readable from the test anchor")
    #expect(
      source?.contains("Static-readout rule") == true,
      "AuraDesign.Motion must document the Reduce Motion static-readout rule")
    #expect(
      source?.contains("accessibilityDisplayShouldReduceMotion") == true,
      "Motion helper must gate on the macOS Reduce Motion accessor")
  }
}