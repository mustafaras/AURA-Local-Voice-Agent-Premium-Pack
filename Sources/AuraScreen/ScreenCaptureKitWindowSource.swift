import AuraCore
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Production `ScreenWindowSource` backed by real `ScreenCaptureKit` calls:
/// `SCShareableContent.current` for enumeration and
/// `SCScreenshotManager.captureImage(contentFilter:configuration:)` for a
/// single on-demand window screenshot.
///
/// A one-shot screenshot API — not a continuous `SCStream` — is used
/// deliberately: the spec's own capture policy is "off until granted and
/// actively needed" with discrete "capture time" freshness metadata per
/// observation, not a continuous video feed, and a live stream would itself
/// contradict "actively needed" by running whether or not anything asked for
/// a fresh observation.
public actor ScreenCaptureKitWindowSource: ScreenWindowSource {
  /// Live `SCWindow`s from the most recent enumeration, keyed by window ID.
  /// `SCWindow` has no public initializer, so capture must reuse the exact
  /// instance that answered `listCapturableWindows()`.
  private var windowsByID: [Int: SCWindow] = [:]

  public init() {}

  public func listCapturableWindows() async throws(AuraError) -> [ScreenWindowDescriptor] {
    let content: SCShareableContent
    do {
      content = try await SCShareableContent.current
    } catch {
      throw AuraError.screenCaptureError(
        "failed to enumerate shareable content: \(error.localizedDescription)")
    }

    var descriptors: [ScreenWindowDescriptor] = []
    var cache: [Int: SCWindow] = [:]
    for window in content.windows {
      let id = Int(window.windowID)
      cache[id] = window
      descriptors.append(
        ScreenWindowDescriptor(
          windowID: id,
          title: window.title,
          applicationBundleIdentifier: window.owningApplication?.bundleIdentifier,
          applicationName: window.owningApplication?.applicationName,
          frameX: window.frame.origin.x,
          frameY: window.frame.origin.y,
          frameWidth: window.frame.size.width,
          frameHeight: window.frame.size.height,
          isOnScreen: window.isOnScreen
        ))
    }
    windowsByID = cache
    return descriptors
  }

  public func captureImage(windowID: Int, region: CaptureRegion?, maxDimension: Int)
    async throws(AuraError) -> CGImage
  {
    guard let window = windowsByID[windowID] else {
      throw AuraError.screenCaptureError(
        "window \(windowID) not found — call listCapturableWindows() first")
    }

    let filter = SCContentFilter(desktopIndependentWindow: window)
    let configuration = SCStreamConfiguration()

    let captureSize: CGSize
    if let region {
      // `SCStreamConfiguration.sourceRect` is specified "in points in the
      // display's logical coordinate system" (SCStream.h), not
      // window-relative — so a window-relative normalized region must be
      // translated into the window's own display-space frame origin first.
      let absoluteRect = Self.absoluteSourceRect(windowFrame: window.frame, region: region)
      configuration.sourceRect = absoluteRect
      captureSize = absoluteRect.size
    } else {
      captureSize = window.frame.size
    }

    let (width, height) = Self.scaledDimensions(
      width: captureSize.width, height: captureSize.height, maxDimension: maxDimension)
    configuration.width = width
    configuration.height = height
    configuration.showsCursor = false

    do {
      return try await SCScreenshotManager.captureImage(
        contentFilter: filter, configuration: configuration)
    } catch {
      throw AuraError.screenCaptureError(
        "failed to capture window \(windowID): \(error.localizedDescription)")
    }
  }

  /// Translate a window-relative, normalized `CaptureRegion` into the
  /// absolute, display-space `CGRect` that `SCStreamConfiguration.sourceRect`
  /// requires: the window's own origin plus the region's fraction of the
  /// window's size.
  static func absoluteSourceRect(windowFrame: CGRect, region: CaptureRegion) -> CGRect {
    CGRect(
      x: windowFrame.origin.x + region.x * windowFrame.size.width,
      y: windowFrame.origin.y + region.y * windowFrame.size.height,
      width: region.width * windowFrame.size.width,
      height: region.height * windowFrame.size.height
    )
  }

  /// Scale `width`x`height` down so neither dimension exceeds `maxDimension`,
  /// preserving aspect ratio. Never scales up.
  static func scaledDimensions(width: Double, height: Double, maxDimension: Int) -> (Int, Int) {
    let cap = Double(maxDimension)
    guard width > 0, height > 0 else { return (1, 1) }
    let scale = min(1.0, cap / max(width, height))
    return (max(1, Int((width * scale).rounded())), max(1, Int((height * scale).rounded())))
  }
}
