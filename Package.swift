// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AURA",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(name: "AURA", targets: ["AURA"]),
        .executable(name: "AuraPluginHost", targets: ["AuraPluginHost"]),
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
        .library(name: "AuraIntent", targets: ["AuraIntent"])
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
                "AuraVSCode"
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
            dependencies: ["AuraCore", "AuraAudio", "AuraShell", "AuraPolicy", "AuraTasks"],
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
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraAudioTests",
            dependencies: ["AuraAudio"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraAutomationTests",
            dependencies: ["AuraAutomation"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraAgentTests",
            dependencies: ["AuraAgent", "AuraAudio", "AuraShell", "AuraPolicy", "AuraTasks", "AuraStore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraStoreTests",
            dependencies: ["AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraSTTTests",
            dependencies: ["AuraSTT"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraPolicyTests",
            dependencies: ["AuraPolicy"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraShellTests",
            dependencies: ["AuraShell"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .target(
            name: "AuraVSCode",
            dependencies: ["AuraCore", "AuraShell"],
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
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
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
        .testTarget(
            name: "AuraSecurityTests",
            dependencies: ["AuraSecurity", "AuraPolicy", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraPluginsTests",
            dependencies: ["AuraPlugins", "AuraPolicy", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .target(
            name: "AuraIntent",
            dependencies: ["AuraCore", "AuraPolicy", "AuraShell", "AuraAutomation", "AuraAgent", "AuraTasks", "AuraContext", "AuraMemory"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "AuraIntentTests",
            dependencies: ["AuraIntent", "AuraPolicy", "AuraShell", "AuraAutomation", "AuraAgent", "AuraTasks", "AuraStore", "AuraMemory", "AuraContext"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraVSCodeTests",
            dependencies: ["AuraVSCode"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraTasksTests",
            dependencies: ["AuraTasks"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraMemoryTests",
            dependencies: ["AuraMemory", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraContextTests",
            dependencies: ["AuraContext", "AuraMemory", "AuraStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        ),
        .testTarget(
            name: "AuraScreenTests",
            dependencies: ["AuraScreen", "AuraPolicy"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
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
                "AuraIntent"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags([
                    "-Xfrontend", "-load-resolved-plugin",
                    "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"
                ])
            ]
        )
    ]
)
