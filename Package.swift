// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OTPilot",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "OTPilot", targets: ["OTPilot"]),
        .library(name: "OTPilotCore", targets: ["OTPilotCore"])
    ],
    targets: [
        .executableTarget(
            name: "OTPilot",
            dependencies: ["OTPilotCore"]
        ),
        .target(
            name: "OTPilotCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
