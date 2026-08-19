// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let testingSwiftSettings: [SwiftSetting] = {
    var settings: [SwiftSetting] = [.swiftLanguageMode(.v6)]
    if let macrosPath = ProcessInfo.processInfo.environment["AURA_TESTING_MACROS_PATH"],
       !macrosPath.isEmpty {
        settings.append(.unsafeFlags([
            "-Xfrontend", "-load-resolved-plugin",
            "-Xfrontend", "\(macrosPath)##TestingMacros"
        ]))
    }
    return settings
}()

let package = Package(
    name: "AURA",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "AURA", targets: ["AURA"]),
        .executable(name: "AuraPluginHost", targets: ["AuraPluginHost"]),
        .executable(name: "AuraAutomationHelper", targets: ["AuraAutomationHelper"]),
        .executable(name: "AuraShellHelper", targets: ["AuraShellHelper"]),
        .executable(
            name: "AuraSafariExtensionHandler", targets: ["AuraSafariExtensionHandler"]),
        .library(name: "AuraCore", targets: ["AuraCore"]),
        .library(name: "AuraAudio", targets: ["AuraAudio"]),
        .library(name: "AuraAutomation", targets: ["AuraAutomation"]),
        .library(name: "AuraAgent", targets: ["AuraAgent"]),
        .library(name: "AuraStore", targets: ["AuraStore"]),
        .library(name: "AuraSTT", targets: ["AuraSTT"]),
        .library(name: "AuraPolicy", targets: ["AuraPolicy"]),
        .library(name: "AuraShell", targets: ["AuraShell"]),
        .library(name: "AuraVSCode", targets: ["AuraVSCode"]),
        .library(name: "AuraTasks", targets: ["AuraTasks"]),
        .library(name: "AuraMemory", targets: ["AuraMemory"]),
        .library(name: "AuraContext", targets: ["AuraContext"]),
        .library(name: "AuraScreen", targets: ["AuraScreen"]),
        .library(name: "AuraComputerUse", targets: ["AuraComputerUse"]),
        .library(name: "AuraSecurity", targets: ["AuraSecurity"]),
        .library(name: "AuraPlugins", targets: ["AuraPlugins"]),
        .library(name: "AuraIntent", targets: ["AuraIntent"]),
        .library(name: "AuraConfig", targets: ["AuraConfig"]),
        .library(name: "AuraProductivity", targets: ["AuraProductivity"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "AURA",
            dependencies: [
                "AuraCore",
                "AuraAudio",
                "AuraSTT",
                "AuraAutomation",
                "AuraAgent",
                "AuraShell",
                "AuraStore",
                "AuraPolicy",
                "AuraTasks",
                "AuraMemory",
                "AuraContext",
                "AuraIntent",
                "AuraComputerUse",
                "AuraScreen",
                "AuraSecurity",
                "AuraPlugins",
                "AuraConfig",
                "AuraVSCode",
                "AuraProductivity"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI", .when(platforms: [.macOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("AVFoundation", .when(platforms: [.macOS])),
                .linkedFramework("Speech", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "AuraCore",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("CryptoKit", .when(platforms: [.macOS])),
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "AuraAudio",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraAutomation",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "AuraAgent",
            dependencies: ["AuraCore", "AuraAudio", "AuraShell", "AuraPolicy", "AuraTasks", "AuraVSCode", "AuraSecurity"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraStore",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraSTT",
            dependencies: ["AuraCore", "AuraAudio"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraPolicy",
            dependencies: ["AuraCore", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraShell",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "AuraCoreTests",
            dependencies: ["AuraCore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraAudioTests",
            dependencies: ["AuraAudio"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraAutomationTests",
            dependencies: ["AuraAutomation"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraAgentTests",
            dependencies: ["AuraAgent", "AuraAudio", "AuraShell", "AuraPolicy", "AuraTasks", "AuraStore", "AuraVSCode"],
            resources: [.copy("Fixtures")],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraStoreTests",
            dependencies: ["AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraSTTTests",
            dependencies: ["AuraSTT", "AuraAudio"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraPolicyTests",
            dependencies: ["AuraPolicy"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraShellTests",
            dependencies: ["AuraShell"],
            swiftSettings: testingSwiftSettings
        ),
        .target(
            name: "AuraVSCode",
            dependencies: ["AuraCore", "AuraPolicy", "AuraShell"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraTasks",
            dependencies: ["AuraCore", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraMemory",
            dependencies: ["AuraCore", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraContext",
            dependencies: ["AuraCore", "AuraStore", "AuraMemory"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraScreen",
            dependencies: ["AuraCore", "AuraPolicy"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("ScreenCaptureKit", .when(platforms: [.macOS])),
                .linkedFramework("Vision", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "AuraComputerUse",
            dependencies: ["AuraCore", "AuraPolicy", "AuraAutomation", "AuraScreen"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "AuraComputerUseTests",
            dependencies: ["AuraComputerUse", "AuraPolicy", "AuraScreen"],
            swiftSettings: testingSwiftSettings
        ),
        .target(
            name: "AuraSecurity",
            dependencies: ["AuraCore", "AuraPolicy", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "AuraPlugins",
            dependencies: ["AuraCore", "AuraPolicy", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "AuraPluginHost",
            dependencies: ["AuraCore", "AuraPlugins"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "AuraAutomationHelper",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "AuraShellHelper",
            dependencies: ["AuraCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        // The native half of the Safari Web Extension. Built as a plain
        // executable and assembled into `AURA.app/Contents/PlugIns` as an
        // `.appex` by `scripts/build-app-bundle.sh`; its `main.swift` calls
        // `NSExtensionMain` so no Xcode-only entry-point setting is needed.
        .executableTarget(
            name: "AuraSafariExtensionHandler",
            dependencies: ["AuraCore", "AuraSecurity", "AuraProductivity"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.macOS])),
                .linkedFramework("SafariServices", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "AuraSecurityTests",
            dependencies: ["AuraSecurity", "AuraPolicy", "AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraPluginsTests",
            dependencies: ["AuraPlugins", "AuraPolicy", "AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .target(
            name: "AuraIntent",
            dependencies: ["AuraCore", "AuraPolicy", "AuraShell", "AuraAutomation", "AuraAgent", "AuraTasks", "AuraContext", "AuraMemory", "AuraSecurity"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraConfig",
            dependencies: ["AuraCore", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "AuraProductivity",
            dependencies: ["AuraCore", "AuraSecurity"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("EventKit", .when(platforms: [.macOS])),
                .linkedFramework("Contacts", .when(platforms: [.macOS])),
                .linkedFramework("Network", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "AuraProductivityTests",
            dependencies: ["AuraProductivity", "AuraSecurity", "AuraCore", "AuraIntent"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraConfigTests",
            dependencies: ["AuraConfig", "AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraAdversarialTests",
            dependencies: [
                "AuraSecurity",
                "AuraPolicy",
                "AuraIntent",
                "AuraMemory",
                "AuraContext",
                "AuraAgent",
                "AuraPlugins",
                "AuraConfig",
                "AuraStore",
                "AuraCore"
            ],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraIntentTests",
            dependencies: ["AuraIntent", "AuraPolicy", "AuraShell", "AuraAutomation", "AuraAgent", "AuraTasks", "AuraStore", "AuraMemory", "AuraContext"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraVSCodeTests",
            dependencies: ["AuraVSCode", "AuraPolicy"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraTasksTests",
            dependencies: ["AuraTasks"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraMemoryTests",
            dependencies: ["AuraMemory", "AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraContextTests",
            dependencies: ["AuraContext", "AuraMemory", "AuraStore"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AuraScreenTests",
            dependencies: ["AuraScreen", "AuraPolicy"],
            swiftSettings: testingSwiftSettings
        ),
        .testTarget(
            name: "AURAIntegrationTests",
            dependencies: [
                "AURA",
                "AuraCore",
                "AuraAudio",
                "AuraSTT",
                "AuraAutomation",
                "AuraAgent",
                "AuraStore",
                "AuraPolicy",
                "AuraShell",
                "AuraVSCode",
                "AuraTasks",
                "AuraMemory",
                "AuraContext",
                "AuraIntent",
                "AuraConfig",
                "AuraSecurity",
                "AuraProductivity"
            , "AuraSafariExtensionHandler"],
            swiftSettings: testingSwiftSettings
        )
    ]
)
