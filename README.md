# AppLovinAdsHandler

A SwiftAds-compatible handler for AppLovin MAX SDK integration. This package provides a complete implementation of the SwiftAds interface for AppLovin's advertising platform.

## Features

- ✅ Full SwiftAds compatibility
- 🎯 Banner, interstitial, and rewarded video ads
- 🔒 Thread-safe with internal `@Locked` property wrapper
- ⚡ Async/await support
- 🔄 Automatic retry logic with exponential backoff
- 📱 iOS 13.0+ support

## Installation

### Swift Package Manager

Add AppLovinAdsHandler to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AppLovinAdsHandler.git", from: "1.0.0")
]
```

## Usage

### Setup

First, configure your AppLovin handler and bootstrap SwiftAds:

```swift
import SwiftAds
import AppLovinAdsHandler

// Initialize with your AppLovin SDK key
let appLovinHandler = AppLovinHandler(
    sdkKey: "YOUR_SDK_KEY",
    doNotSell: nil,
    hasUserConsent: true,
    showMediationDebugger: false
)

// Bootstrap SwiftAds with the AppLovin handler
AdsSystem.bootstrap(appLovinHandler)
```

### Display Ads

Once configured, use the standard SwiftAds interface:

```swift
import SwiftAds

let ads = Ads()

// Show interstitial ad
try await ads.showInterstitial(id: "your-interstitial-id")

// Show rewarded video
try await ads.showRewarderVideo(id: "your-rewarded-id")

// Load banner ad
let bannerView = try await ads.loadBanner(
    id: "your-banner-id",
    in: viewController,
    size: .standart
)
view.addSubview(bannerView)
```

### Configuration Options

The `AppLovinHandler` initializer supports several configuration options:

```swift
let handler = AppLovinHandler(
    sdkKey: "YOUR_SDK_KEY",
    doNotSell: false,                    // CCPA compliance
    hasUserConsent: true,                // GDPR compliance
    showMediationDebugger: true,         // Debug mode (DEBUG builds only)
    builderBlock: { builder in           // Additional SDK configuration
        // Configure builder if needed
    },
    settings: { settings in              // SDK settings customization
        // Configure settings if needed
    }
)
```

### Banner Sizes

AppLovinAdsHandler supports all SwiftAds banner sizes:

- `.standart` - Standard banner
- `.medium` - Medium rectangle
- `.large` - Large banner
- `.adaptive` - Adaptive banner (full width)
- `.custom(width, height)` - Custom size

For adaptive and custom banners, the handler automatically configures AppLovin's adaptive banner parameters.

## Error Handling

The handler includes built-in retry logic with exponential backoff (up to 6 attempts). Failed operations throw `AppLovinError` which wraps the underlying `MAError`.

```swift
do {
    try await ads.showInterstitial(id: "ad-id")
} catch let error as AppLovinError {
    print("AppLovin error: \\(error.localizedDescription)")
} catch {
    print("General error: \\(error)")
}
```

## Requirements

- iOS 13.0+
- Swift 5.9+
- AppLovin MAX SDK 13.0.0+
- SwiftAds 1.0.0+

## Dependencies

- [SwiftAds](https://github.com/dankinsoid/swift-ads) - Unified ads interface
- [AppLovin MAX SDK](https://github.com/AppLovin/AppLovin-MAX-Swift-Package) - AppLovin's advertising SDK

## License

This project is available under the MIT license.