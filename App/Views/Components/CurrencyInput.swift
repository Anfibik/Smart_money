import SwiftUI

enum CurrencyInputStyle {
    case roundedBorder
    case card
}

struct CurrencyInput: View {
    @Binding var text: String

    let placeholder: String
    var currencyCode: String? = nil
    var allowsNegative = false
    var maximumFractionDigits = 2
    var style: CurrencyInputStyle = .roundedBorder
    var autoFocus = false
    var showsDoneButton = true
    var externalFocus: Binding<Bool>? = nil

    @FocusState private var isFocused: Bool
    @State private var didRequestAutoFocus = false

    var body: some View {
        styledField
            .onAppear {
                updateText(text)
                let shouldFocus = externalFocus?.wrappedValue == true || autoFocus
                guard shouldFocus, !didRequestAutoFocus else { return }
                didRequestAutoFocus = true
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            .onChange(of: text) { _, newValue in
                updateText(newValue)
            }
            .onChange(of: isFocused) { _, newValue in
                if externalFocus?.wrappedValue != newValue {
                    externalFocus?.wrappedValue = newValue
                }
            }
            .onChange(of: externalFocus?.wrappedValue ?? false) { _, newValue in
                guard externalFocus != nil, isFocused != newValue else { return }
                isFocused = newValue
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if showsDoneButton, isFocused {
                        Spacer()
                        Button("Готово") {
                            isFocused = false
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var styledField: some View {
        switch style {
        case .roundedBorder:
            field
                .textFieldStyle(.roundedBorder)
        case .card:
            field
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? AppTheme.accent : AppTheme.mutedIcon.opacity(0.35),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: inputBinding,
                prompt: Text(placeholder)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.95))
            )
            .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if let currencyCode {
                Text(AppCurrencyFormatter.symbol(for: currencyCode))
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityHidden(true)
            }
        }
    }

    private var inputBinding: Binding<String> {
        Binding(
            get: { text },
            set: { updateText($0) }
        )
    }

    private func updateText(_ input: String) {
        let sanitized = CurrencyInputFormatter.sanitized(
            input,
            allowsNegative: allowsNegative,
            maximumFractionDigits: maximumFractionDigits
        )
        if text != sanitized {
            text = sanitized
        }
    }
}
