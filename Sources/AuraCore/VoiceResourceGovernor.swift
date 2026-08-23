import Dispatch
import Foundation

/// Workloads that compete for the limited memory and thermal budget of the
/// primary 16 GB Apple Silicon profile.
public enum VoiceWorkload: String, Codable, Sendable, Equatable, CaseIterable {
  case stt
  case ttsNeural
  case reasoning
  case screenVision
  case codingAgent
}

public enum VoiceWorkloadPriority: Int, Codable, Sendable, Equatable, Comparable, CaseIterable {
  case background = 0
  case interactive = 1
  case speech = 2
  case emergency = 3

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public enum VoiceResourcePressure: String, Codable, Sendable, Equatable, CaseIterable {
  case normal
  case warning
  case critical
}

public enum VoiceThermalState: String, Codable, Sendable, Equatable, CaseIterable {
  case nominal
  case fair
  case serious
  case critical
}

public struct VoiceResourceGovernorConfiguration: Codable, Sendable, Equatable {
  /// Conservative resident-memory budget for AURA workloads, not total system
  /// memory. This intentionally leaves headroom for macOS and the UI.
  public var residentMemoryBudgetMB: UInt64
  public var defaultReservationMB: UInt64
  public var circuitFailureLimit: UInt32
  public var idleUnloadAfterSeconds: Double

  public init(
    residentMemoryBudgetMB: UInt64 = 6_144,
    defaultReservationMB: UInt64 = 512,
    circuitFailureLimit: UInt32 = 3,
    idleUnloadAfterSeconds: Double = 300
  ) {
    self.residentMemoryBudgetMB = residentMemoryBudgetMB
    self.defaultReservationMB = defaultReservationMB
    self.circuitFailureLimit = circuitFailureLimit
    self.idleUnloadAfterSeconds = idleUnloadAfterSeconds
  }

  public func validate() throws(AuraError) {
    guard residentMemoryBudgetMB > 0 else {
      throw AuraError.invalidConfiguration("voice resident memory budget must be positive")
    }
    guard defaultReservationMB > 0 else {
      throw AuraError.invalidConfiguration("voice default reservation must be positive")
    }
    guard circuitFailureLimit > 0 else {
      throw AuraError.invalidConfiguration("voice circuit failure limit must be positive")
    }
    guard idleUnloadAfterSeconds > 0 else {
      throw AuraError.invalidConfiguration("voice idle unload duration must be positive")
    }
  }
}

public struct VoiceResourceDecision: Codable, Sendable, Equatable {
  public let granted: Bool
  public let workload: VoiceWorkload
  public let estimatedMemoryMB: UInt64
  public let pressure: VoiceResourcePressure
  public let thermalState: VoiceThermalState
  public let reason: String

  public init(
    granted: Bool,
    workload: VoiceWorkload,
    estimatedMemoryMB: UInt64,
    pressure: VoiceResourcePressure,
    thermalState: VoiceThermalState,
    reason: String
  ) {
    self.granted = granted
    self.workload = workload
    self.estimatedMemoryMB = estimatedMemoryMB
    self.pressure = pressure
    self.thermalState = thermalState
    self.reason = reason
  }
}

public struct VoiceResourceGovernorSnapshot: Codable, Sendable, Equatable {
  public let pressure: VoiceResourcePressure
  public let thermalState: VoiceThermalState
  public let residentMemoryBudgetMB: UInt64
  public let reservedMemoryMB: UInt64
  public let activeWorkloads: [String: UInt64]
  public let openCircuits: [VoiceWorkload]
  public let observedAt: Date

  public init(
    pressure: VoiceResourcePressure,
    thermalState: VoiceThermalState,
    residentMemoryBudgetMB: UInt64,
    reservedMemoryMB: UInt64,
    activeWorkloads: [String: UInt64],
    openCircuits: [VoiceWorkload],
    observedAt: Date = Date()
  ) {
    self.pressure = pressure
    self.thermalState = thermalState
    self.residentMemoryBudgetMB = residentMemoryBudgetMB
    self.reservedMemoryMB = reservedMemoryMB
    self.activeWorkloads = activeWorkloads
    self.openCircuits = openCircuits
    self.observedAt = observedAt
  }
}

/// Actor-isolated admission control for local voice and model workloads.
///
/// The governor does not pretend to measure a model's exact resident set. It
/// admits bounded reservations, reacts to OS memory-pressure/thermal signals,
/// and exposes the resulting decision so callers can unload or fall back. A
/// denied reservation must never be silently treated as a ready model.
public actor VoiceResourceGovernor {
  private let configuration: VoiceResourceGovernorConfiguration
  private let physicalMemoryBytes: UInt64
  private let thermalStateProvider: @Sendable () -> VoiceThermalState
  private let now: @Sendable () -> Date

  private var pressure: VoiceResourcePressure = .normal
  private var thermalState: VoiceThermalState
  private var reservations: [VoiceWorkload: UInt64] = [:]
  private var lastActiveAt: [VoiceWorkload: Date] = [:]
  private var failureCounts: [VoiceWorkload: UInt32] = [:]
  private var openCircuits: Set<VoiceWorkload> = []
  private var memoryPressureSource: (any DispatchSourceMemoryPressure)?
  private var thermalObservationTask: Task<Void, Never>?
  private var idleUnloadTask: Task<Void, Never>?

  public init(
    configuration: VoiceResourceGovernorConfiguration = VoiceResourceGovernorConfiguration(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    thermalStateProvider: @escaping @Sendable () -> VoiceThermalState = {
      VoiceResourceGovernor.map(ProcessInfo.processInfo.thermalState)
    },
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.configuration = configuration
    self.physicalMemoryBytes = physicalMemoryBytes
    self.thermalStateProvider = thermalStateProvider
    self.now = now
    self.thermalState = thermalStateProvider()
  }

  public func start() {
    guard memoryPressureSource == nil else { return }
    let source = DispatchSource.makeMemoryPressureSource(
      eventMask: [.normal, .warning, .critical],
      queue: DispatchQueue(label: "ai.aura.resource-governor", qos: .utility))
    memoryPressureSource = source
    source.setEventHandler { [weak self, weak source] in
      guard let self, let source else { return }
      let eventRawValue = source.data.rawValue
      Task { await self.apply(memoryPressureRawValue: eventRawValue) }
    }
    source.setCancelHandler {}
    source.activate()

    thermalObservationTask = Task { [weak self] in
      guard let self else { return }
      for await _ in NotificationCenter.default.notifications(
        named: ProcessInfo.thermalStateDidChangeNotification)
      {
        guard !Task.isCancelled else { return }
        await self.refreshThermalState()
      }
    }

    // R7 resource-governor control: an idle workload's reservation is
    // released after `idleUnloadAfterSeconds` of inactivity. The caller
    // must re-reserve before the next use; this unload only drops the
    // reservation, it never touches the underlying model process, so it is
    // a signal to callers to unload rather than a force-kill. STT and
    // neural-TTS are the speech-priority workloads and may still be dropped
    // so the 16 GB profile does not hold a stale reservation indefinitely.
    idleUnloadTask = Task { [weak self] in
      guard let self else { return }
      // Poll at half the configured idle interval so an unload is not late
      // by more than half a window, bounded to a sane minimum cadence.
      let window = max(1, configuration.idleUnloadAfterSeconds)
      let cadence = max(0.5, window / 2)
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(cadence))
        guard !Task.isCancelled else { return }
        await self.unloadIdleReservations()
      }
    }
  }

  public func stop() {
    memoryPressureSource?.cancel()
    memoryPressureSource = nil
    thermalObservationTask?.cancel()
    thermalObservationTask = nil
    idleUnloadTask?.cancel()
    idleUnloadTask = nil
    reservations.removeAll()
    lastActiveAt.removeAll()
  }

  /// Drop every reservation that has been idle for at least
  /// `idleUnloadAfterSeconds`. Returns the workloads that were unloaded so
  /// callers can react (e.g. mark the model not-ready).
  @discardableResult
  public func unloadIdleReservations() -> [VoiceWorkload] {
    let threshold = configuration.idleUnloadAfterSeconds
    guard threshold > 0 else { return [] }
    let cutoff = now().addingTimeInterval(-threshold)
    var unloaded: [VoiceWorkload] = []
    for (workload, activeAt) in lastActiveAt where activeAt < cutoff {
      if reservations.removeValue(forKey: workload) != nil {
        lastActiveAt.removeValue(forKey: workload)
        unloaded.append(workload)
      }
    }
    return unloaded
  }

  public func reserve(
    _ workload: VoiceWorkload,
    estimatedMemoryMB: UInt64? = nil,
    priority: VoiceWorkloadPriority = .interactive
  ) -> VoiceResourceDecision {
    let amount = max(1, estimatedMemoryMB ?? configuration.defaultReservationMB)

    if openCircuits.contains(workload) {
      return decision(
        granted: false, workload: workload, amount: amount,
        reason: "resource circuit is open after repeated failures")
    }

    if thermalState == .critical && workload != .stt && workload != .ttsNeural {
      return decision(
        granted: false, workload: workload, amount: amount,
        reason: "critical thermal state permits speech capture/fallback only")
    }

    if pressure == .critical && workload != .stt && workload != .ttsNeural {
      return decision(
        granted: false, workload: workload, amount: amount,
        reason: "critical memory pressure permits speech capture/fallback only")
    }

    let current = reservations.values.reduce(0, +)
    guard current + amount <= configuration.residentMemoryBudgetMB else {
      let lowerPriorityActive = reservations.keys.contains {
        Self.priority(for: $0) < priority
      }
      let reason =
        lowerPriorityActive
        ? "resident budget is full; caller must preempt lower-priority work explicitly"
        : "resident budget is full; no lower-priority workload may be preempted implicitly"
      return decision(granted: false, workload: workload, amount: amount, reason: reason)
    }

    reservations[workload, default: 0] += amount
    lastActiveAt[workload] = now()
    return decision(
      granted: true, workload: workload, amount: amount, reason: "reservation admitted")
  }

  public func release(_ workload: VoiceWorkload, estimatedMemoryMB: UInt64? = nil) {
    guard let current = reservations[workload] else { return }
    let amount = estimatedMemoryMB ?? current
    if amount >= current {
      reservations.removeValue(forKey: workload)
      lastActiveAt.removeValue(forKey: workload)
    } else {
      reservations[workload] = current - amount
      lastActiveAt[workload] = now()
    }
  }

  public func recordFailure(_ workload: VoiceWorkload) {
    let count = failureCounts[workload, default: 0] &+ 1
    failureCounts[workload] = count
    if count >= configuration.circuitFailureLimit {
      openCircuits.insert(workload)
      reservations.removeValue(forKey: workload)
    }
  }

  public func resetCircuit(_ workload: VoiceWorkload) {
    failureCounts[workload] = 0
    openCircuits.remove(workload)
  }

  public func update(pressure: VoiceResourcePressure) {
    self.pressure = pressure
  }

  public func update(thermalState: VoiceThermalState) {
    self.thermalState = thermalState
  }

  public func snapshot() -> VoiceResourceGovernorSnapshot {
    return VoiceResourceGovernorSnapshot(
      pressure: pressure,
      thermalState: thermalState,
      residentMemoryBudgetMB: configuration.residentMemoryBudgetMB,
      reservedMemoryMB: reservations.values.reduce(0, +),
      activeWorkloads: Dictionary(
        uniqueKeysWithValues: reservations.map {
          ($0.key.rawValue, $0.value)
        }),
      openCircuits: openCircuits.sorted { $0.rawValue < $1.rawValue },
      observedAt: now())
  }

  public func physicalMemoryMB() -> UInt64 {
    physicalMemoryBytes / 1_024 / 1_024
  }

  private func decision(
    granted: Bool,
    workload: VoiceWorkload,
    amount: UInt64,
    reason: String
  ) -> VoiceResourceDecision {
    VoiceResourceDecision(
      granted: granted,
      workload: workload,
      estimatedMemoryMB: amount,
      pressure: pressure,
      thermalState: thermalState,
      reason: reason)
  }

  private func apply(memoryPressureRawValue rawValue: DispatchSource.MemoryPressureEvent.RawValue) {
    let event = DispatchSource.MemoryPressureEvent(rawValue: rawValue)
    if event.contains(.critical) {
      pressure = .critical
    } else if event.contains(.warning) {
      pressure = .warning
    } else if event.contains(.normal) {
      pressure = .normal
    }
  }

  private func refreshThermalState() {
    thermalState = thermalStateProvider()
  }

  private static func priority(for workload: VoiceWorkload) -> VoiceWorkloadPriority {
    switch workload {
    case .stt, .ttsNeural: .speech
    case .reasoning, .screenVision: .interactive
    case .codingAgent: .background
    }
  }

  public static func map(_ state: ProcessInfo.ThermalState) -> VoiceThermalState {
    switch state {
    case .nominal: .nominal
    case .fair: .fair
    case .serious: .serious
    case .critical: .critical
    @unknown default: .serious
    }
  }
}
