import SwiftUI

/// The signature component (ui-improvement-plan/13-advanced-surfaces.md §1):
/// one geometry whose every layer is driven by real signals — the honesty
/// contract made visible. **What it shows is what is happening.**
///
/// Inputs are exactly the three the spec names: `status`, `inputLevel`
/// (from `AudioLevelBridge`, `nil` when not listening), and
/// `isSpeakingResponse`. The Orb never computes state itself — the mapping
/// from inputs to layers is pure logic (`AuraOrbStateMapping`) so it is
/// unit-testable without rendering, and every layer names its data source:
///
/// | Layer | Source of truth |
/// | --- | --- |
/// | Core | `status` color map (rest luminance at idle) |
/// | Inner ring | static hairline (the "calibration" line) |
/// | Outer ring | state instrument: live waveform arc (listening, from the
/// real level), orbiting arc (thinking), ≤3-bar equalizer (speaking, from
/// real TTS state), amber segment (restricted), critical segment (error),
/// hairline (idle) |
/// | Field | faint radial gradient; opacity follows the real level when
/// listening, fixed otherwise |
///
/// No synthetic data may drive any layer. Under Reduce Motion the Orb renders
/// its current state as a still instrument readout — ring pose + text, never
/// blank (11-motion-system.md §6).
struct AuraOrb: View {
  let status: AuraAppStatus
  let inputLevel: Double?
  let isSpeakingResponse: Bool
  /// The UI language for the still-readout text; threaded by every caller so
  /// the readout follows the interface language (same discipline as
  /// `AuraMessageBubble.language`).
  let language: AuraUILanguage
  /// Restricted-state reason text, rendered beside the ring (never color
  /// alone). Rendered only for `.restricted`.
  var restrictedReason: String = ""

  /// SwiftUI environment view of Reduce Motion. The pure mapping stays
  /// environment-free; this is the render-side gate for the thinking arc's
  /// orbit (the one continuous motion the Orb contains).
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let mapping = AuraOrbStateMapping.resolve(
      status: status, inputLevel: inputLevel, isSpeakingResponse: isSpeakingResponse,
      language: language)
    VStack(spacing: AuraDesign.Spacing.s) {
      instrument(mapping)
      if status == .restricted, !restrictedReason.isEmpty {
        Text(restrictedReason)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(AuraDesign.Palette.cautious)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(stillReadout(mapping))
  }

  /// Ring + core. The thinking arc orbits via a transform-only rotation on a
  /// 30 fps TimelineView (13 §1.2, 11 §5 budget); Reduce Motion renders the
  /// static pose — still a full readout, never blank.
  private func instrument(_ mapping: AuraOrbStateMapping.Layers) -> some View {
    ZStack {
      field(mapping)
      orbitingRing(mapping)
      core(mapping)
    }
    .frame(width: AuraOrbLayout.size, height: AuraOrbLayout.size)
  }

  /// The ring layer; under an active thinking state (and motion enabled) the
  /// arc orbits via a transform-only rotation on a 30 fps TimelineView.
  @ViewBuilder
  private func orbitingRing(_ mapping: AuraOrbStateMapping.Layers) -> some View {
    if status == .thinking, !reduceMotion {
      TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
        ringCanvas(mapping)
          .rotationEffect(.degrees(AuraOrbStateMapping.orbitAngle(at: timeline.date)))
      }
    } else {
      ringCanvas(mapping)
    }
  }

  /// Outer ring: the instrument readout per state (13 §1.2). Drawn on
  /// `Canvas` — vector strokes, no blur cost at the ring layer.
  private func ringCanvas(_ mapping: AuraOrbStateMapping.Layers) -> some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = size.width / 2 - AuraOrbLayout.ringInset
      for stroke in mapping.ringSegments {
        var path = Path()
        path.addArc(
          center: center, radius: radius,
          startAngle: .degrees(stroke.startAngle), endAngle: .degrees(stroke.endAngle),
          clockwise: false)
        context.stroke(
          path, with: .color(mapping.stateColor.opacity(stroke.opacity)),
          style: StrokeStyle(
            lineWidth: stroke.lineWidth, lineCap: .round,
            dash: stroke.dash ?? [], dashPhase: 0))
      }
    }
    .allowsHitTesting(false)
  }

  // MARK: - Layers (13 §1.1 anatomy)

  /// Field: the faint radial "aura". Listening: opacity follows the real
  /// level. Otherwise: fixed faint gradient from the state color.
  private func field(_ mapping: AuraOrbStateMapping.Layers) -> some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [mapping.stateColor.opacity(mapping.fieldOpacity), .clear],
          center: .center, startRadius: 0, endRadius: AuraOrbLayout.size / 2))
      .allowsHitTesting(false)
  }

  /// Core: the luminous disc. Idle keeps minimum luminance; active states
  /// carry the state color at full strength.
  private func core(_ mapping: AuraOrbStateMapping.Layers) -> some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [mapping.stateColor, mapping.stateColor.opacity(0.55)],
          center: .center, startRadius: 0, endRadius: AuraOrbLayout.coreRadius))
      .frame(width: AuraOrbLayout.coreRadius * 2, height: AuraOrbLayout.coreRadius * 2)
      .opacity(mapping.coreOpacity)
      .allowsHitTesting(false)
  }

  /// The VoiceOver still readout: the real state name, plus the restricted
  /// reason when present. State is never color-only information.
  private func stillReadout(_ mapping: AuraOrbStateMapping.Layers) -> String {
    guard status == .restricted, !restrictedReason.isEmpty else {
      return mapping.accessibilityLabel
    }
    return "\(mapping.accessibilityLabel). \(restrictedReason)"
  }
}

/// Fixed instrument geometry for the Orb (13 §1.3 — one geometry, five
/// homes); every other view still sizes from design tokens.
enum AuraOrbLayout {
  static let size: CGFloat = 96
  static let coreRadius: CGFloat = 22
  static let ringInset: CGFloat = 6
  static let hairlineWidth: CGFloat = 1.5
}

/// Pure state→layer mapping (G1-6: extracted from the view for testing).
/// Deterministic over its inputs — no time, no randomness, no environment —
/// so a test matrix can pin all six behaviors (13 §1.2 table).
enum AuraOrbStateMapping {
  /// One outer-ring stroke segment.
  struct RingSegment: Equatable {
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let opacity: Double
    /// Dash pattern; `nil` = solid. The restricted segment uses dashes so
    /// the state survives without color.
    let dash: [CGFloat]?

    static func solid(
      _ start: Double, _ end: Double, width: CGFloat, opacity: Double = 1
    ) -> RingSegment {
      RingSegment(
        startAngle: start, endAngle: end, lineWidth: width, opacity: opacity, dash: nil)
    }

    static func dashed(
      _ start: Double, _ end: Double, width: CGFloat, opacity: Double = 1
    ) -> RingSegment {
      RingSegment(
        startAngle: start, endAngle: end, lineWidth: width, opacity: opacity,
        dash: [3, 4])
    }
  }

  /// The resolved layer values for one input state.
  struct Layers: Equatable {
    let stateColor: Color
    let coreOpacity: Double
    /// Field (aura) gradient opacity — level-driven only while listening.
    let fieldOpacity: Double
    let ringSegments: [RingSegment]
    /// VoiceOver readout naming the real state.
    let accessibilityLabel: String
  }

  /// Fixed geometry for a full 360° hairline ring (idle/stopped/starting):
  /// arcs cannot express a full circle, so the hairline is four quadrant
  /// strokes.
  static let quadrants: [(Double, Double)] = [(0, 90), (90, 180), (180, 270), (270, 360)]

  /// Resolve the layers for one state. `inputLevel` reaches the ring only
  /// while listening; `isSpeakingResponse` only while speaking.
  static func resolve(
    status: AuraAppStatus, inputLevel: Double?, isSpeakingResponse: Bool,
    language: AuraUILanguage
  ) -> Layers {
    switch status {
    case .idle, .starting, .stopped:
      return Layers(
        stateColor: AuraDesign.statusColor(status),
        coreOpacity: 0.55,
        fieldOpacity: 0.10,
        ringSegments: quadrantHairlines(),
        accessibilityLabel: AuraCopy.text(stillReadoutKey(for: status), language: language))
    case .listening:
      return listeningLayers(inputLevel: inputLevel, language: language)
    case .thinking:
      // Orbiting arc: a fixed quarter-arc pose; the view animates rotation
      // transform-only. The mapping stays deterministic.
      return Layers(
        stateColor: AuraDesign.statusColor(.thinking),
        coreOpacity: 0.9,
        fieldOpacity: 0.14,
        ringSegments: [.solid(270, 345, width: AuraOrbLayout.hairlineWidth * 2)],
        accessibilityLabel: AuraCopy.text("a11y.orb.thinking", language: language))
    case .speaking:
      return speakingLayers(isSpeakingResponse: isSpeakingResponse, language: language)
    case .restricted:
      return Layers(
        stateColor: AuraDesign.statusColor(.restricted),
        coreOpacity: 0.85,
        fieldOpacity: 0.12,
        ringSegments: [
          .dashed(150, 330, width: AuraOrbLayout.hairlineWidth * 2.5)
        ],
        accessibilityLabel: AuraCopy.text("a11y.orb.restricted", language: language))
    case .error:
      return Layers(
        stateColor: AuraDesign.statusColor(.error),
        coreOpacity: 1,
        fieldOpacity: 0.16,
        ringSegments: [
          .solid(120, 240, width: AuraOrbLayout.hairlineWidth * 2.5)
        ],
        accessibilityLabel: AuraCopy.text("a11y.orb.error", language: language))
    }
  }

  /// Listening ring: the live waveform arc — the ring *is* the mic meter.
  /// The level (0…1) maps onto arc span and stroke weight; `nil` level
  /// (listening, no frame yet) renders the minimum arc rather than a fake
  /// mid reading.
  static func listeningLayers(inputLevel: Double?, language: AuraUILanguage) -> Layers {
    let level = inputLevel ?? 0
    let clamped = min(max(level, 0), 1)
    let span = 45 + 270 * clamped
    return Layers(
      stateColor: AuraDesign.statusColor(.listening),
      coreOpacity: 0.9,
      fieldOpacity: 0.08 + 0.3 * clamped,
      ringSegments: [
        .solid(
          -span / 2, span / 2,
          width: AuraOrbLayout.hairlineWidth + 2 * clamped)
      ],
      accessibilityLabel: AuraCopy.text("a11y.orb.listening", language: language))
  }

  /// Speaking ring: ≤3 equalizer bars drawn as radial arc strokes on the
  /// ring's track, from the real TTS state. The bars *are* the speaking
  /// state; a future real TTS level signal (UI-2) can scale bar widths
  /// without changing this shape contract. A speaking signal without
  /// `isSpeakingResponse` still reads as speaking via the hairline pose,
  /// never as idle.
  static func speakingLayers(isSpeakingResponse: Bool, language: AuraUILanguage) -> Layers {
    let color = AuraDesign.statusColor(.speaking)
    let label = AuraCopy.text("a11y.orb.speaking", language: language)
    guard isSpeakingResponse else {
      return Layers(
        stateColor: color,
        coreOpacity: 0.9,
        fieldOpacity: 0.12,
        ringSegments: quadrantHairlines(),
        accessibilityLabel: label)
    }
    return Layers(
      stateColor: color,
      coreOpacity: 0.95,
      fieldOpacity: 0.12,
      ringSegments: equalizerSegments(),
      accessibilityLabel: label)
  }

  /// Deterministic 3-bar equalizer pose (arc segments at 3 ring positions).
  static func equalizerSegments() -> [RingSegment] {
    [
      .solid(300, 340, width: 2),
      .solid(350, 10, width: 4),
      .solid(20, 60, width: 2),
    ]
  }

  static func quadrantHairlines() -> [RingSegment] {
    quadrants.map { start, end in
      .solid(start, end, width: AuraOrbLayout.hairlineWidth, opacity: 0.5)
    }
  }

  /// Copy keys for the rest states (idle/starting/stopped) — the same state
  /// words the status pill uses, kept as separate keys because the pill's
  /// `AuraAppStatus.title(for:)` is a runtime-string mapper, not copy-table
  /// surface.
  static func stillReadoutKey(for status: AuraAppStatus) -> String {
    switch status {
    case .idle: return "a11y.orb.idle"
    case .starting: return "a11y.orb.starting"
    case .stopped: return "a11y.orb.stopped"
    default: return "a11y.orb.idle"
    }
  }

  /// Constant angular velocity for the thinking orbit: 120°/s (one revolution
  /// per 3 s), rendered at ≤30 fps by the TimelineView schedule.
  static let orbitDegreesPerSecond: Double = 120
  /// Fixed epoch so the angle is a pure function of the timeline date.
  static let orbitEpoch = Date(timeIntervalSince1970: 0)

  /// Pure orbit angle: elapsed seconds × degrees per second. The rotation
  /// effect wraps modulo 360 by construction.
  static func orbitAngle(at date: Date) -> Double {
    date.timeIntervalSince(orbitEpoch) * orbitDegreesPerSecond
  }
}