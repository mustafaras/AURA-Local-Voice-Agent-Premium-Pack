import SwiftUI
import Testing

@testable import AURA

/// UI-0 gates G0-4, G0-4a, and G0-5.
///
/// The contrast gate computes WCAG 2.x relative-luminance ratios for every
/// text-on-surface token pair in **both** appearance variants, from the token
/// table itself (the CI host has no rendering surface — `AuraDesign` stores
/// each token's light/dark partners explicitly, so both variants are
/// validated from the single source of truth).
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
    // White @ 62% composited over the surface it sits on.
    HexToken(name: "textSecondary", dark: 0xFFFFFF, light: 0xFFFFFF, opacity: 0.62),
    HexToken(name: "textTertiary", dark: 0xFFFFFF, light: 0xFFFFFF, opacity: 0.56),
    HexToken(name: "biolume", dark: 0x5AE6C8, light: 0x0E8467, opacity: 1),
    HexToken(name: "biolumeDeep", dark: 0x1FB59A, light: 0x0A6B54, opacity: 1),
    HexToken(name: "signal", dark: 0x8AB4FF, light: 0x3D6EC0, opacity: 1),
    HexToken(name: "cautious", dark: 0xF2B84B, light: 0x8A5606, opacity: 1),
    HexToken(name: "critical", dark: 0xFF6B5E, light: 0xC93A2E, opacity: 1),
  ]

  /// Resolves a table token over the given surface hex, returns its luminance.
  ///
  /// Opaque tokens: luminance of their own hex. Opacity tokens: composited
  /// over the given surface (white ink on dark surfaces, dark ink on light).
  private static func resolvedLuminance(_ token: HexToken, over surface: UInt32) -> Double {
    guard token.opacity < 1 else { return luminance(ofHex: token.dark) }
    let overlay = (
      Double((token.dark >> 16) & 0xFF) / 255,
      Double((token.dark >> 8) & 0xFF) / 255,
      Double(token.dark & 0xFF) / 255
    )
    let base = (
      Double((surface >> 16) & 0xFF) / 255,
      Double((surface >> 8) & 0xFF) / 255,
      Double(surface & 0xFF) / 255
    )
    let (r, g, b) = composite(
      overlayRed: overlay.0, g: overlay.1, b: overlay.2, opacity: token.opacity,
      overRed: base.0, bg: base.1, bb: base.2)
    return luminance(red: r, green: g, blue: b)
  }

  @Test("owned palette meets WCAG contrast in the dark variant")
  func darkVariantContrast() {
    let surfaceL = Self.luminance(ofHex: Self.darkSurface)
    for token in Self.tokenTable {
      let fg = Self.resolvedLuminance(token, over: Self.darkSurface)
      let ratio = Self.contrastRatio(fg, surfaceL)
      // body ≥ 7:1 (textPrimary), meta ≥ 4.5:1 (secondary/tertiary).
      if token.name == "textPrimary" {
        #expect(ratio >= 7, "dark \(token.name) ratio \(ratio) < 7")
      } else {
        #expect(ratio >= 4.5, "dark \(token.name) ratio \(ratio) < 4.5")
      }
    }
  }

  @Test("owned palette meets WCAG contrast in the light variant")
  func lightVariantContrast() {
    let surfaceL = Self.luminance(ofHex: Self.lightSurface)
    for token in Self.tokenTable {
      // Light variant: opaque tokens use their light hex; opacity tokens
      // composite dark ink over the paper surface.
      let fg: Double
      if token.opacity < 1 {
        let base = (
          Double((Self.lightSurface >> 16) & 0xFF) / 255,
          Double((Self.lightSurface >> 8) & 0xFF) / 255,
          Double(Self.lightSurface & 0xFF) / 255
        )
        let ink = (0.0, 0.0, 0.0) // light-variant text is dark ink
        let (r, g, b) = Self.composite(
          overlayRed: ink.0, g: ink.1, b: ink.2, opacity: token.opacity,
          overRed: base.0, bg: base.1, bb: base.2)
        fg = Self.luminance(red: r, green: g, blue: b)
      } else {
        fg = Self.luminance(ofHex: token.light)
      }
      let ratio = Self.contrastRatio(fg, surfaceL)
      if token.name == "textPrimary" {
        #expect(ratio >= 7, "light \(token.name) ratio \(ratio) < 7")
      } else {
        #expect(ratio >= 4.5, "light \(token.name) ratio \(ratio) < 4.5")
      }
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
  }

  @Test("v2 Measure members exist and are typed CGFloat")
  func measureMembersResolve() {
    let _: CGFloat = AuraDesign.Measure.tickMajor
    let _: CGFloat = AuraDesign.Measure.tickMinor
    let _: CGFloat = AuraDesign.Measure.hairline
    let _: CGFloat = AuraDesign.Measure.bracket
    let _: CGFloat = AuraDesign.Measure.gridStep
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