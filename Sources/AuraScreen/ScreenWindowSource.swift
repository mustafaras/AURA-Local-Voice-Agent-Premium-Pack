import AuraCore
import CoreGraphics
import Foundation

/// Enumerates capturable windows and produces an image for one of them.
///
/// A single protocol (rather than two) because the real implementation needs
/// to resolve a `ScreenWindowDescriptor.windowID` back to a live `SCWindow`
/// (which has no public initializer) — the same object that answered
/// `listCapturableWindows()` is the one that must be used to capture, so
/// splitting enumeration and capture into unrelated types would force an
/// awkward shared cache across two independent conformers.
public protocol ScreenWindowSource: Sendable {
  func listCapturableWindows() async throws(AuraError) -> [ScreenWindowDescriptor]

  /// Capture `windowID`, optionally scoped to `region` (window-relative,
  /// normalized `[0, 1]`). `region == nil` captures the whole window.
  func captureImage(windowID: Int, region: CaptureRegion?, maxDimension: Int) async throws(AuraError)
    -> CGImage
}
