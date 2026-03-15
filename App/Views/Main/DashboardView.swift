//
//  DashboardView.swift
//  Smart_money
//
//  Created by Filobokov Andrii on 15.02.2026.
//

import SwiftUI

struct DashboardView: View {
    let distribution: BudgetDistribution
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сводка")
                .font(.title2.bold())

            Text("Доход: \(currency(distribution.income))")
                .font(.headline)

            ForEach(distribution.categoryAllocations) { category in
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.type.title)
                        .font(.headline)

                    Text("\(currency(category.allocatedAmount)) • \(category.percentage, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
