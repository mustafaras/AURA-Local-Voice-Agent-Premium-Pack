import AuraCore
@testable import AuraScreen
import CoreGraphics
import Foundation

/// A tiny, deterministic real `CGImage` for tests that need to exercise
/// image-shaped code paths (content hashing, dimension math) without a live
/// capture.
func makeTestImage(width: Int = 2, height: Int = 2) -> CGImage {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()!
}

actor ScriptedWindowSource: ScreenWindowSource {
  private var windows: [ScreenWindowDescriptor]
  private(set) var captureImageCallCount = 0
  private(set) var lastRequestedRegion: CaptureRegion?
  var imageToReturn: CGImage

  init(windows: [ScreenWindowDescriptor], imageToReturn: CGImage = makeTestImage()) {
    self.windows = windows
    self.imageToReturn = imageToReturn
  }

  func listCapturableWindows() async throws(AuraError) -> [ScreenWindowDescriptor] {
    windows
  }

  func captureImage(windowID: Int, region: CaptureRegion?, maxDimension: Int) async throws(AuraError)
    -> CGImage
  {
    captureImageCallCount += 1
    lastRequestedRegion = region
    guard windows.contains(where: { $0.windowID == windowID }) else {
      throw AuraError.screenCaptureError("window \(windowID) not found")
    }
    return imageToReturn
  }
}

actor ScriptedTextRecognizer: TextRecognizing {
  var regionsToReturn: [RecognizedTextRegion]

  init(regionsToReturn: [RecognizedTextRegion] = []) {
    self.regionsToReturn = regionsToReturn
  }

  func recognizeText(in image: CGImage) async throws(AuraError) -> [RecognizedTextRegion] {
    regionsToReturn
  }
}

actor ScriptedSecureFieldDetector: SecureFieldDetecting {
  var focusedBundleIdentifiers: Set<String>

  init(focusedBundleIdentifiers: Set<String> = []) {
    self.focusedBundleIdentifiers = focusedBundleIdentifiers
  }

  func isSecureFieldFocused(applicationBundleIdentifier: String) async -> Bool {
    focusedBundleIdentifiers.contains(applicationBundleIdentifier)
  }
}

func makeWindow(
  id: Int, title: String? = "Window", bundleID: String? = "com.example.app",
  appName: String? = "Example", isOnScreen: Bool = true
) -> ScreenWindowDescriptor {
  ScreenWindowDescriptor(
    windowID: id, title: title, applicationBundleIdentifier: bundleID, applicationName: appName,
    frameX: 0, frameY: 0, frameWidth: 800, frameHeight: 600, isOnScreen: isOnScreen)
}
