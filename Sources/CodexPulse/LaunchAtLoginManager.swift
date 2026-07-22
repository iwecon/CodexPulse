import Foundation
import OSLog
import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    private static let appServiceConfiguredKey = "launchAtLogin.appServiceConfigured"
    private static let logger = Logger(subsystem: "Codex Pulse", category: "LaunchAtLogin")

    static func enableIfNeeded(
        bundle: Bundle = .main,
        isDebugBuild: Bool = currentBuildIsDebug,
        defaults: UserDefaults = .standard
    ) {
        guard isEligible(bundleURL: bundle.bundleURL, isDebugBuild: isDebugBuild) else { return }
        enableAppServiceIfNeeded(defaults: defaults)
    }

    nonisolated static func isEligible(bundleURL: URL, isDebugBuild: Bool) -> Bool {
        !isDebugBuild && bundleURL.pathExtension.lowercased() == "app"
    }

    nonisolated static var currentBuildIsDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func enableAppServiceIfNeeded(defaults: UserDefaults) {
        guard !defaults.bool(forKey: appServiceConfiguredKey) else { return }

        let service = SMAppService.mainApp
        switch service.status {
        case .enabled, .requiresApproval:
            defaults.set(true, forKey: appServiceConfiguredKey)
        case .notRegistered:
            do {
                try service.register()
                defaults.set(true, forKey: appServiceConfiguredKey)
            } catch {
                logger.error("注册系统登录项失败：\(error.localizedDescription, privacy: .public)")
            }
        case .notFound:
            logger.error("系统未找到主应用登录项")
        @unknown default:
            logger.error("系统返回了未知的登录项状态")
        }
    }
}
