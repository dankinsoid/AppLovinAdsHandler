import AppLovinSDK
import Foundation
import SwiftAds
import UIKit

/// AppLovin MAX SDK implementation of the SwiftAds `AdsHandler` protocol.
///
/// This handler provides integration with AppLovin's MAX mediation platform,
/// supporting banner, interstitial, and rewarded video ads with built-in retry logic.
///
/// - Tip: For improved reliability, wrap this handler with `ExponentialRetryAdsHandler`:
/// ```swift
/// let appLovinHandler = AppLovinHandler(sdkKey: "your-sdk-key")
/// AdsSystem.bootstrap(robustHandler.withExponentialRetry())
/// ```
public final class AppLovinHandler: AdsHandler {
	private let sdkKey: String
	@Locked private var didInit = false
	private let doNotSell: Bool?
	private let hasUserConsent: Bool?
	@Locked private var interstitials: [String: Interstitial] = [:]
	@Locked private var rewardedVideoDelegate: [String: RewardedVideoDelegate] = [:]
	private let builderBlock: ((ALSdkInitializationConfigurationBuilder) -> Void)?
	private let settings: ((ALSdkSettings) -> Void)?
	private let showMediationDebugger: Bool
	@Locked private var initTask: Task<Void, Never>?

	/// Creates an AppLovin ads handler.
	/// - Parameters:
	///   - sdkKey: Your AppLovin SDK key from the dashboard
	///   - doNotSell: CCPA "Do Not Sell" preference (nil = not set)
	///   - hasUserConsent: GDPR user consent status (nil = not set)
	///   - showMediationDebugger: Shows mediation debugger in DEBUG builds
	///   - builderBlock: Additional SDK initialization configuration
	///   - settings: SDK settings customization
	public init(
		sdkKey: String,
		doNotSell: Bool? = nil,
		hasUserConsent: Bool? = nil,
		showMediationDebugger: Bool = false,
		builderBlock: ((ALSdkInitializationConfigurationBuilder) -> Void)? = nil,
		settings: ((ALSdkSettings) -> Void)? = nil
	) {
		self.sdkKey = sdkKey
		self.hasUserConsent = hasUserConsent
		self.doNotSell = doNotSell
		self.settings = settings
		self.builderBlock = builderBlock
		self.showMediationDebugger = showMediationDebugger
	}

	/// Initializes the AppLovin SDK with privacy settings and configuration.
	/// This method is called automatically by other ad methods and handles initialization only once.
	public func initAds() async throws {
		guard !didInit else { return }
		if let initTask {
			return await initTask.value
		}
		if let doNotSell {
			ALPrivacySettings.setDoNotSell(doNotSell)
		}
		if let hasUserConsent {
			ALPrivacySettings.setHasUserConsent(hasUserConsent)
		}

		settings?(ALSdk.shared().settings)
		initTask = Task { [builderBlock] in
			await ALSdk.shared().initialize(
				with: ALSdkInitializationConfiguration(sdkKey: sdkKey) { [builderBlock] builder in
					builder.mediationProvider = ALMediationProviderMAX
					builderBlock?(builder)
				}
			)
		}
		_ = await initTask?.value
		didInit = true
		#if DEBUG
			guard showMediationDebugger else { return }
			ALSdk.shared().showMediationDebugger()
		#endif
	}

	/// Loads and returns a banner ad view.
	/// - Parameters:
	///   - controller: View controller to display the banner in
	///   - size: Banner size (supports adaptive sizing)
	///   - id: AppLovin ad unit identifier
	///   - placement: Optional placement identifier for targeting
	/// - Returns: Configured banner view ready for display
	@MainActor
	public func loadBanner(
		in _: UIViewController,
		size: Ads.Size,
		id: String,
		placement: String?
	) async throws -> UIView {
		try await initAds()
		let view = Banner(adUnitIdentifier: id)
		view.delegate = view
		view.placement = placement
		switch size {
		case .standart:
			break
		case .medium:
			break
		case .large:
			break
		case .adaptive:
			view.setExtraParameterForKey("adaptive_banner", value: "true")
			view.setLocalExtraParameterForKey("adaptive_banner_width", value: UIScreen.main.bounds.width)
			if let size = view.adFormat?.adaptiveSize {
				view.frame.size = size
			}
		case let .custom(width, height):
			view.setExtraParameterForKey("adaptive_banner", value: "true")
			view.setLocalExtraParameterForKey("adaptive_banner_width", value: width)
			view.setLocalExtraParameterForKey("adaptive_banner_height", value: height)
			view.frame.size = CGSize(width: width, height: height)
		}
		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Banner, Error>) in
			view.loadContinuation = continuation
			view.loadAd()
		}
	}

	/// Preloads an interstitial ad for faster display.
	/// - Parameters:
	///   - id: AppLovin ad unit identifier
	///   - placement: Optional placement identifier for targeting
	public func loadInterstitial(id: String, placement _: String?) async throws {
		try await initAds()
		if let interstitial = interstitials[id] {
			try await interstitial.loadTask?.value
			return
		}
		let interstitial = Interstitial(adUnitIdentifier: id)
		interstitial.delegate = interstitial
		interstitials[id] = interstitial
		let task = Task { [weak interstitial] in
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				interstitial?.loadContinuation = continuation
				interstitial?.load()
			}
		}
		interstitial.loadTask = task
		try await task.value
	}

	/// Preloads a rewarded video ad for faster display.
	/// - Parameters:
	///   - id: AppLovin ad unit identifier
	///   - placement: Optional placement identifier for targeting
	public func loadRewarderVideo(id: String, placement _: String?) async throws {
		try await initAds()
		if let delegate = rewardedVideoDelegate[id] {
			try await delegate.loadTask?.value
			return
		}
		let delegate = RewardedVideoDelegate(video: MARewardedAd.shared(withAdUnitIdentifier: id))
		rewardedVideoDelegate[id] = delegate
		let task = Task { [weak delegate] in
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				delegate?.loadContinuation = continuation
				delegate?.video.load()
			}
		}
		delegate.loadTask = task
		try await task.value
	}

	/// Shows an interstitial ad, loading it first if necessary.
	/// - Parameters:
	///   - controller: View controller to present the ad from
	///   - id: AppLovin ad unit identifier
	///   - placement: Optional placement identifier for targeting
	@MainActor
	public func showInterstitial(from controller: UIViewController, id: String, placement: String?) async throws {
		try await loadInterstitial(id: id, placement: placement)
		let interstitial = interstitials[id] ?? Interstitial(adUnitIdentifier: id)
		interstitial.delegate = interstitial
		interstitials[id] = interstitial
		guard interstitial.isReady, interstitial.showContinuation == nil else { return }
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			interstitial.showContinuation = continuation
			interstitial.show(forPlacement: placement, customData: nil, viewController: controller)
		}
	}

	/// Shows a rewarded video ad, loading it first if necessary.
	/// - Parameters:
	///   - controller: View controller to present the ad from
	///   - id: AppLovin ad unit identifier
	///   - placement: Optional placement identifier for targeting
	@MainActor
	public func showRewarderVideo(from controller: UIViewController, id: String, placement: String?) async throws {
		try await loadRewarderVideo(id: id, placement: placement)
		let delegate = rewardedVideoDelegate[id] ?? RewardedVideoDelegate(video: MARewardedAd.shared(withAdUnitIdentifier: id))
		rewardedVideoDelegate[id] = delegate
		guard delegate.video.isReady, delegate.showContinuation == nil else { return }
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			delegate.showContinuation = continuation
			delegate.video.show(forPlacement: placement, customData: nil, viewController: controller)
		}
	}
}

private extension AppLovinHandler {
	final class Banner: MAAdView, MAAdViewAdDelegate {
		var loadContinuation: CheckedContinuation<Banner, Error>?

		func didLoad(_: MAAd) {
			loadContinuation?.resume(returning: self)
			loadContinuation = nil
		}

		func didFailToLoadAd(forAdUnitIdentifier _: String, withError error: MAError) {
			loadContinuation?.resume(throwing: AppLovinError(error: error))
			loadContinuation = nil
		}

		func didExpand(_: MAAd) {}
		func didCollapse(_: MAAd) {}
		func didDisplay(_: MAAd) {}
		func didHide(_: MAAd) {}
		func didClick(_: MAAd) {}
		func didFail(toDisplay _: MAAd, withError _: MAError) {}
	}
}

private struct AppLovinError: LocalizedError {
	let error: MAError
	var errorDescription: String? { error.message }
}

private extension AppLovinHandler {
	final class Interstitial: MAInterstitialAd, MAAdDelegate {
		var loadContinuation: CheckedContinuation<Void, Error>?
		var showContinuation: CheckedContinuation<Void, Error>?
		var loadTask: Task<Void, Error>?

		func didLoad(_: MAAd) {
			loadContinuation?.resume()
			loadContinuation = nil
		}

		func didFailToLoadAd(forAdUnitIdentifier _: String, withError error: MAError) {
			loadContinuation?.resume(throwing: AppLovinError(error: error))
			loadContinuation = nil
		}

		func didDisplay(_: MAAd) {}

		func didHide(_: MAAd) {
			showContinuation?.resume()
			showContinuation = nil
			load()
		}

		func didClick(_: MAAd) {}

		func didFail(toDisplay _: MAAd, withError error: MAError) {
			showContinuation?.resume(throwing: AppLovinError(error: error))
			showContinuation = nil
			load()
		}
	}
}

private extension AppLovinHandler {
	final class RewardedVideoDelegate: NSObject, MARewardedAdDelegate {
		var loadContinuation: CheckedContinuation<Void, Error>?
		var showContinuation: CheckedContinuation<Void, Error>?
		var loadTask: Task<Void, Error>?
		var video: MARewardedAd

		init(video: MARewardedAd) {
			self.video = video
			super.init()
			video.delegate = self
		}

		func didLoad(_: MAAd) {
			loadContinuation?.resume()
			loadContinuation = nil
		}

		func didFailToLoadAd(forAdUnitIdentifier _: String, withError error: MAError) {
			loadContinuation?.resume(throwing: AppLovinError(error: error))
			loadContinuation = nil
		}

		func didDisplay(_: MAAd) {}

		func didHide(_: MAAd) {
			showContinuation?.resume()
			showContinuation = nil
			video.load()
		}

		func didClick(_: MAAd) {}

		func didFail(toDisplay _: MAAd, withError error: MAError) {
			showContinuation?.resume(throwing: AppLovinError(error: error))
			showContinuation = nil
			video.load()
		}

		func didRewardUser(for _: MAAd, with _: MAReward) {}
	}
}
