import Foundation

struct AppInstallMetadata {
    let firstLaunchDate: Date
    let firstLaunchAppVersion: String
    let firstLaunchBuildNumber: String
}

final class AppInstallMetadataService {
    private enum Keys {
        static let didRegisterFirstLaunch = "app_install.did_register_first_launch"
        static let firstLaunchDate = "app_install.first_launch_date"
        static let firstLaunchAppVersion = "app_install.first_launch_app_version"
        static let firstLaunchBuildNumber = "app_install.first_launch_build_number"
    }

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.now = now
    }

    func registerFirstLaunchIfNeeded() {
        guard !defaults.bool(forKey: Keys.didRegisterFirstLaunch) else { return }

        defaults.set(true, forKey: Keys.didRegisterFirstLaunch)
        defaults.set(now(), forKey: Keys.firstLaunchDate)
        defaults.set(appVersion, forKey: Keys.firstLaunchAppVersion)
        defaults.set(buildNumber, forKey: Keys.firstLaunchBuildNumber)
    }

    func loadMetadata() -> AppInstallMetadata? {
        guard defaults.bool(forKey: Keys.didRegisterFirstLaunch),
              let firstLaunchDate = defaults.object(forKey: Keys.firstLaunchDate) as? Date else {
            return nil
        }

        return AppInstallMetadata(
            firstLaunchDate: firstLaunchDate,
            firstLaunchAppVersion: defaults.string(forKey: Keys.firstLaunchAppVersion) ?? "unknown",
            firstLaunchBuildNumber: defaults.string(forKey: Keys.firstLaunchBuildNumber) ?? "unknown"
        )
    }

    private var appVersion: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var buildNumber: String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }
}
