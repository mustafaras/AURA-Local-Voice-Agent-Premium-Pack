import AuraAgent
import AuraAudio
import AuraAutomation
import AuraComputerUse
import AuraConfig
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPlugins
import AuraPolicy
import AuraSTT
import AuraScreen
import AuraSecurity
import AuraShell
import AuraStore
import AuraTasks
import AuraVSCode
import Dispatch
import Foundation

extension AuraKernel {
  // MARK: - Signal handling

  func installSignalHandlers() {
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    intSource.setEventHandler { [weak self] in
      Task { await self?.triggerShutdown() }
    }
    intSource.resume()
    sigintSource = intSource

    let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    termSource.setEventHandler { [weak self] in
      Task { await self?.triggerShutdown() }
    }
    termSource.resume()
    sigtermSource = termSource
  }

  func triggerShutdown() {
    shutdownContinuation?.resume()
    shutdownContinuation = nil
  }
}
