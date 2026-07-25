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
        .library(name: "AuraCore", targets: ["AuraCore"]),
        .library(name: "AuraAudio", targets: ["AuraAudio"]),
        .library(name: "AuraAutomation", targets: ["AuraAutomation"]),
        .library(name: "AuraAgent", targets: ["AuraAgent"]),
        .library(name: "AuraStore", targets: ["AuraStore"]),
        .library(name: "AuraSTT", targets: ["AuraSTT"]),
        .library(name: "AuraPolicy", targets: ["AuraPolicy"]),
        .library(name: "AuraShell", targets: ["AuraShell"]),
        .library(name: "AuraVSCode", targets: ["AuraVSCode"]),
        .library(name: "AuraTasks", targets: ["AuraTasks"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "AURA",
            dependencies: [
                "AuraCore",
                "AuraAudio",
                "AuraAutomation",
                "AuraAgent",
                "AuraStore",
                "AuraPolicy"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
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
                "AuraTasks"
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
