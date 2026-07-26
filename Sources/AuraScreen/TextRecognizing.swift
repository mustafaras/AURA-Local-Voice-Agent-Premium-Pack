import AuraCore
import CoreGraphics
import Foundation

/// Extracts text regions from a captured window image, so
/// `RedactionPipeline` can pattern-match recognized text against secret
/// shapes. Real pixel content can only be pattern-matched after OCR — this
/// boundary is what lets `RedactionPipeline` be tested deterministically
/// with scripted text, independent of whether real OCR is available.
public protocol TextRecognizing: Sendable {
  func recognizeText(in image: CGImage) async throws(AuraError) -> [RecognizedTextRegion]
}
