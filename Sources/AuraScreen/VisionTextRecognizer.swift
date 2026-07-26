import AuraCore
import CoreGraphics
import Foundation
import Vision

/// Production `TextRecognizing` backed by the real `Vision` framework
/// (`VNRecognizeTextRequest`/`VNImageRequestHandler`).
public struct VisionTextRecognizer: TextRecognizing {
  public init() {}

  public func recognizeText(in image: CGImage) async throws(AuraError) -> [RecognizedTextRegion] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      throw AuraError.screenCaptureError("OCR failed: \(error.localizedDescription)")
    }

    guard let observations = request.results else { return [] }
    return observations.compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      let box = observation.boundingBox
      return RecognizedTextRegion(
        text: candidate.string,
        boundingBoxX: box.origin.x,
        boundingBoxY: box.origin.y,
        boundingBoxWidth: box.size.width,
        boundingBoxHeight: box.size.height
      )
    }
  }
}
