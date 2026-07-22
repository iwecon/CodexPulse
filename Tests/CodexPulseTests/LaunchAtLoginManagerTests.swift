import Foundation
import Testing
@testable import CodexPulse

@Test(arguments: [false, true])
func rawExecutableIsNeverEligibleForLaunchAtLogin(isDebugBuild: Bool) {
    let executableURL = URL(fileURLWithPath: "/usr/local/bin/Codex Pulse")

    #expect(!LaunchAtLoginManager.isEligible(
        bundleURL: executableURL,
        isDebugBuild: isDebugBuild
    ))
}

@Test func debugAppIsNotEligibleForLaunchAtLogin() {
    let bundleURL = URL(fileURLWithPath: "/Applications/Codex Pulse.app")

    #expect(!LaunchAtLoginManager.isEligible(bundleURL: bundleURL, isDebugBuild: true))
}

@Test func releaseAppIsEligibleForLaunchAtLogin() {
    let bundleURL = URL(fileURLWithPath: "/Applications/Codex Pulse.app")

    #expect(LaunchAtLoginManager.isEligible(bundleURL: bundleURL, isDebugBuild: false))
}
