import Foundation

struct FreeCapitalCoverageTargets: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let cardDeficits = FreeCapitalCoverageTargets(rawValue: 1 << 0)
    static let emergencyFund = FreeCapitalCoverageTargets(rawValue: 1 << 1)
}

struct FreeCapitalCoveragePolicy: Codable, Hashable {
    var targets: FreeCapitalCoverageTargets

    static let none = FreeCapitalCoveragePolicy(targets: [])
    static let cardDeficitsOnly = FreeCapitalCoveragePolicy(
        targets: [.cardDeficits]
    )
    static let emergencyFundOnly = FreeCapitalCoveragePolicy(
        targets: [.emergencyFund]
    )
    static let allOnboardingDeficits = FreeCapitalCoveragePolicy(
        targets: [.cardDeficits, .emergencyFund]
    )

    var coversCardDeficits: Bool {
        targets.contains(.cardDeficits)
    }

    var coversEmergencyFund: Bool {
        targets.contains(.emergencyFund)
    }

    var isEnabled: Bool {
        !targets.isEmpty
    }

    func settingCardDeficitsCoverage(_ isEnabled: Bool) -> FreeCapitalCoveragePolicy {
        setting(.cardDeficits, isEnabled: isEnabled)
    }

    func settingEmergencyFundCoverage(_ isEnabled: Bool) -> FreeCapitalCoveragePolicy {
        setting(.emergencyFund, isEnabled: isEnabled)
    }

    private func setting(
        _ target: FreeCapitalCoverageTargets,
        isEnabled: Bool
    ) -> FreeCapitalCoveragePolicy {
        var updatedTargets = targets
        if isEnabled {
            updatedTargets.insert(target)
        } else {
            updatedTargets.remove(target)
        }
        return FreeCapitalCoveragePolicy(targets: updatedTargets)
    }
}
