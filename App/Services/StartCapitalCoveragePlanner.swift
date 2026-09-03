import Foundation

struct StartCapitalCoverageCardDeficit: Identifiable, Hashable {
    let id: UUID
    let name: String
    let amount: Double
}

struct StartCapitalCoveragePlan: Hashable {
    let availableFreeCapital: Double
    let essentialsDeficit: Double
    let wantsDeficit: Double
    let financeCardDeficits: [StartCapitalCoverageCardDeficit]
    let emergencyFundDeficit: Double
    let projectedEssentialsDeficit: Double
    let projectedWantsDeficit: Double
    let projectedFinanceCardDeficits: [StartCapitalCoverageCardDeficit]
    let projectedEmergencyFundDeficit: Double
    let projectedDistribution: Double
    let projectedRemainingFreeCapital: Double

    var cardDeficitTotal: Double {
        essentialsDeficit
            + wantsDeficit
            + financeCardDeficits.reduce(0) { $0 + $1.amount }
    }

    var hasCardDeficits: Bool {
        cardDeficitTotal > 0.01
    }

    var hasEmergencyFundDeficit: Bool {
        emergencyFundDeficit > 0.01
    }

    var projectedCardDeficitTotal: Double {
        projectedEssentialsDeficit
            + projectedWantsDeficit
            + projectedFinanceCardDeficits.reduce(0) { $0 + $1.amount }
    }

    var coveredCardDeficitAmount: Double {
        max(0, cardDeficitTotal - projectedCardDeficitTotal)
    }

    var coveredEmergencyFundAmount: Double {
        max(0, emergencyFundDeficit - projectedEmergencyFundDeficit)
    }

}

struct StartCapitalCoveragePlanner {
    func makePlan(
        uncoveredPreview: StartOnboardingPreview,
        projectedPreview: StartOnboardingPreview
    ) -> StartCapitalCoveragePlan {
        let available = uncoveredPreview.configuration.remainingFreeCapital
        let projectedRemaining = projectedPreview.configuration.remainingFreeCapital

        return StartCapitalCoveragePlan(
            availableFreeCapital: available,
            essentialsDeficit: categoryDeficit(.essentials, in: uncoveredPreview),
            wantsDeficit: categoryDeficit(.wants, in: uncoveredPreview),
            financeCardDeficits: financeDeficits(in: uncoveredPreview),
            emergencyFundDeficit: emergencyFundDeficit(in: uncoveredPreview),
            projectedEssentialsDeficit: categoryDeficit(.essentials, in: projectedPreview),
            projectedWantsDeficit: categoryDeficit(.wants, in: projectedPreview),
            projectedFinanceCardDeficits: financeDeficits(in: projectedPreview),
            projectedEmergencyFundDeficit: emergencyFundDeficit(in: projectedPreview),
            projectedDistribution: max(0, available - projectedRemaining),
            projectedRemainingFreeCapital: projectedRemaining
        )
    }

    private func categoryDeficit(
        _ categoryType: ExpenseCategoryType,
        in preview: StartOnboardingPreview
    ) -> Double {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == categoryType })?
            .deficitAmount ?? 0
    }

    private func financeDeficits(
        in preview: StartOnboardingPreview
    ) -> [StartCapitalCoverageCardDeficit] {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == .savings })?
            .subcategoryAllocations
            .filter {
                $0.systemKey != .emergencyFund
                    && $0.deficitAmount > 0.01
            }
            .map {
                StartCapitalCoverageCardDeficit(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.deficitAmount
                )
            } ?? []
    }

    private func emergencyFundDeficit(
        in preview: StartOnboardingPreview
    ) -> Double {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == .savings })?
            .subcategoryAllocations
            .first(where: { $0.systemKey == .emergencyFund })?
            .deficitAmount ?? 0
    }
}
