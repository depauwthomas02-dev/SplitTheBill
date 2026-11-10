// swift-tools-version: 5.10
// Paquet utilisé uniquement pour tester la logique (lecture du ticket, calcul du partage)
// sans simulateur : `swift test` depuis le dossier ios/. L'app, elle, se construit avec SplitTheBill.xcodeproj.
import PackageDescription

let package = Package(
    name: "SplitCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "SplitCore", path: "SplitTheBill/Core"),
        .testTarget(name: "SplitCoreTests", dependencies: ["SplitCore"], path: "Tests/SplitCoreTests"),
    ]
)
