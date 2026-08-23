import AuraAudio
import AuraCore
import Foundation
import Testing

struct AuraAudioTests {

  @Test func ringBufferOverwritesOldestWhenFull() {
    let capacity = 3
    let buffer = AudioRingBuffer(capacity: capacity)

    let frame1 = AudioFrame(samples: [1.0], timestamp: 1.0, sequenceIndex: 1)
    let frame2 = AudioFrame(samples: [2.0], timestamp: 2.0, sequenceIndex: 2)
    let frame3 = AudioFrame(samples: [3.0], timestamp: 3.0, sequenceIndex: 3)
    let frame4 = AudioFrame(samples: [4.0], timestamp: 4.0, sequenceIndex: 4)

    buffer.append(frame1)
    buffer.append(frame2)
    buffer.append(frame3)
    buffer.append(frame4)

    let snapshot = buffer.snapshot()
    #expect(snapshot.count == capacity)
    #expect(snapshot.map(\.sequenceIndex) == [2, 3, 4])
  }

  @Test func ringBufferClearEmptiesContents() {
    let buffer = AudioRingBuffer(capacity: 2)
    buffer.append(AudioFrame(samples: [1.0], timestamp: 1.0, sequenceIndex: 1))
    buffer.clear()
    #expect(buffer.snapshot().isEmpty)
  }

  @Test func ringBufferFindsRetainedFrameBySequenceIndex() {
    let buffer = AudioRingBuffer(capacity: 3)
    buffer.append(AudioFrame(samples: [1.0], timestamp: 1.0, sequenceIndex: 1))
    buffer.append(AudioFrame(samples: [2.0], timestamp: 2.0, sequenceIndex: 2))
    buffer.append(AudioFrame(samples: [3.0], timestamp: 3.0, sequenceIndex: 3))

    #expect(buffer.frame(sequenceIndex: 2)?.samples == [2.0])
    #expect(buffer.frame(sequenceIndex: 99) == nil)
  }

  @Test func audioFrameImmutabilityAndDiscontinuityFlag() {
    let frame = AudioFrame(
      samples: [0.5, -0.5],
      timestamp: 1.5,
      sequenceIndex: 42,
      isDiscontinuity: true
    )
    #expect(frame.samples == [0.5, -0.5])
    #expect(frame.timestamp == 1.5)
    #expect(frame.sequenceIndex == 42)
    #expect(frame.isDiscontinuity)
  }
}

/// Simple non-actor container used only in tests to collect values across
/// `@Sendable` handlers without capturing a `var`.
private final class MutexBox<T>: @unchecked Sendable {
  private var value: T
  private let lock = NSLock()

  init(_ value: T) {
    self.value = value
  }

  func withLock<R>(_ body: (inout T) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}
