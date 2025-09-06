// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppLovinAdsHandler",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "AppLovinAdsHandler",
            targets: ["AppLovinAdsHandler"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/dankinsoid/swift-ads.git", from: "1.0.2"),
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", from: "13.0.0"),
    ],
    targets: [
        .target(
            name: "AppLovinAdsHandler",
            dependencies: [
                .product(name: "SwiftAds", package: "swift-ads"),
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
            ]
        ),
        .testTarget(
            name: "AppLovinAdsHandlerTests",
            dependencies: ["AppLovinAdsHandler"]
        ),
    ]
)
