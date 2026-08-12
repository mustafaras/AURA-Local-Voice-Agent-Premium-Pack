import AuraCore
import Foundation

/// Pure, deterministic redaction logic: given OCR-recognized text regions, a
/// secure-field flag, and configured user-defined regions/patterns, produces
/// the list of regions that must be masked.
///
/// No I/O, no capture, no OCR of its own — exactly the boundary that lets
/// "redaction correctness verified with adversarial fixtures" be a real,
/// deterministic unit-test property rather than something that depends on a
/// live screen and live OCR results.
public struct RedactionPipeline: Sendable {
  /// Financial-data shape: a run of 13-19 digits (allowing space/dash
  /// separators), independent of the user-configurable `redactionPatterns`
  /// list — this category is always detected, not opt-in.
  private static let financialDataPattern: NSRegularExpression? = try? NSRegularExpression(
    pattern: "\\b(?:\\d[ -]?){13,19}\\b")

  /// Authentication-code shape: a labeled 4-8 digit code, independent of the
  /// user-configurable `redactionPatterns` list.
  private static let authenticationCodePattern: NSRegularExpression? = try? NSRegularExpression(
    pattern: "\\b(?:code|otp)[:\\s]+\\d{4,8}\\b", options: [.caseInsensitive])

  public init() {}

  /// Compute redaction matches for one captured window.
  ///
  /// - Parameters:
  ///   - recognizedText: OCR output for the captured image; empty if OCR is
  ///     disabled or unavailable.
  ///   - isSecureFieldFocused: whether Accessibility reports a secure text
  ///     field currently focused in the captured application. When true, the
  ///     entire frame is masked as `.secureTextField` — the pixels behind a
  ///     focused password field, and any surrounding context, are not
  ///     trusted to be safely OCR-redactable region-by-region.
  ///   - userDefinedRegions: always-masked regions regardless of content.
  ///   - configuredPatterns: additional user-configured secret patterns,
  ///     matched against recognized text and masked as
  ///     `.patternMatchedSecret`.
  public func redactions(
    recognizedText: [RecognizedTextRegion],
    isSecureFieldFocused: Bool,
    userDefinedRegions: [UserDefinedRedactionRegion],
    configuredPatterns: [RedactionRule]
  ) -> [RedactionMatch] {
    if isSecureFieldFocused {
      return [
        RedactionMatch(
          category: .secureTextField, boundingBoxX: 0, boundingBoxY: 0, boundingBoxWidth: 1,
          boundingBoxHeight: 1, patternDescription: "focused secure text field")
      ]
    }

    var matches: [RedactionMatch] = []

    for region in userDefinedRegions {
      matches.append(
        RedactionMatch(
          category: .userDefinedRegion, boundingBoxX: region.originX, boundingBoxY: region.originY,
          boundingBoxWidth: region.width, boundingBoxHeight: region.height,
          patternDescription: "user-defined region"))
    }

    for textRegion in recognizedText {
      if let category = builtInCategory(for: textRegion.text) {
        matches.append(match(for: textRegion, category: category))
        continue
      }
      if matchesAny(configuredPatterns, in: textRegion.text) {
        matches.append(match(for: textRegion, category: .patternMatchedSecret))
      }
    }

    return matches
  }

  private func builtInCategory(for text: String) -> RedactionCategory? {
    // A built-in pattern is a privacy invariant. If Foundation ever rejects
    // one of these fixed literals, mask the OCR region rather than allowing
    // sensitive text to pass through because detection became unavailable.
    guard let financialDataPattern = Self.financialDataPattern,
      let authenticationCodePattern = Self.authenticationCodePattern
    else {
      return .patternMatchedSecret
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    if financialDataPattern.firstMatch(in: text, range: range) != nil {
      return .financialData
    }
    if authenticationCodePattern.firstMatch(in: text, range: range) != nil {
      return .authenticationCode
    }
    return nil
  }

  private func matchesAny(_ patterns: [RedactionRule], in text: String) -> Bool {
    patterns.contains { rule in
      text.range(of: rule.pattern, options: .regularExpression) != nil
    }
  }

  private func match(for region: RecognizedTextRegion, category: RedactionCategory)
    -> RedactionMatch
  {
    RedactionMatch(
      category: category, boundingBoxX: region.boundingBoxX, boundingBoxY: region.boundingBoxY,
      boundingBoxWidth: region.boundingBoxWidth, boundingBoxHeight: region.boundingBoxHeight,
      patternDescription: "\(category.rawValue)-shaped text")
  }
}
