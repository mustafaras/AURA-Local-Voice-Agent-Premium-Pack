import AuraCore
import Foundation

/// A bounded, volatile, single-producer/single-consumer ring buffer for audio frames.
///
/// The buffer is intended for wake-word pre-roll and short-term context. It does
/// not allocate, log, or perform file I/O inside the real-time write path. All
/// storage is in-memory and volatile; data is discarded when the buffer wraps or
/// when the service stops.
public final class AudioRingBuffer: @unchecked Sendable {
  private let capacity: Int
  private let lock = NSLock()
  private var storage: [AudioFrame]
  private var writeIndex: Int = 0
  private var frameCount: UInt64 = 0

  /// Create a ring buffer that holds at most `capacity` frames.
  public init(capacity: Int) {
    precondition(capacity > 0, "ring buffer capacity must be positive")
    self.capacity = capacity
    self.storage = []
    // Pre-allocate capacity to avoid growth in the real-time path.
    self.storage.reserveCapacity(capacity)
  }

  /// Number of frames currently stored.
  public var count: Int {
    lock.withLock { storage.count }
  }

  /// Maximum number of frames the buffer can hold.
  public var maxCount: Int {
    capacity
  }

  /// Append a frame. If the buffer is full the oldest frame is overwritten.
  ///
  /// This method is lock-free in intent but uses a short lock because Swift
  /// collections are not safe for concurrent access. The critical section does
  /// no allocation, file I/O, or model work.
  public func append(_ frame: AudioFrame) {
    lock.withLock {
      if storage.count < capacity {
        storage.append(frame)
      } else {
        storage[writeIndex] = frame
      }
      writeIndex = (writeIndex + 1) % capacity
      frameCount &+= 1
    }
  }

  /// Return a snapshot of frames in temporal order (oldest first).
  public func snapshot() -> [AudioFrame] {
    lock.withLock {
      if storage.count < capacity {
        return Array(storage)
      }
      var ordered: [AudioFrame] = []
      ordered.reserveCapacity(capacity)
      for offset in 0..<capacity {
        let index = (writeIndex + offset) % capacity
        ordered.append(storage[index])
      }
      return ordered
    }
  }

  /// Total number of frames ever written (modulo UInt64 wrap).
  public var totalFramesWritten: UInt64 {
    lock.withLock { frameCount }
  }

  /// The most recently appended frame, or `nil` if nothing has been
  /// written yet. Used by `AuraAudio.latestFrame()` to bridge real capture
  /// output to downstream consumers (`WakeWordPipeline`/`STTPipeline`)
  /// whose own `AudioFrameEvent` subscription carries no sample data.
  public func latest() -> AudioFrame? {
    lock.withLock {
      guard !storage.isEmpty else { return nil }
      if storage.count < capacity {
        return storage.last
      }
      let lastWrittenIndex = (writeIndex - 1 + capacity) % capacity
      return storage[lastWrittenIndex]
    }
  }

  /// Remove all stored frames.
  public func clear() {
    lock.withLock {
      storage.removeAll(keepingCapacity: true)
      writeIndex = 0
    }
  }
}
