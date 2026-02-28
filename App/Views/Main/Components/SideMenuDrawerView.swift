import SwiftUI

struct SideMenuItemDescriptor: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isEnabled: Bool

    init(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

struct SideMenuDrawerView: View {
    let items: [SideMenuItemDescriptor]
    let onSelectItem: (SideMenuItemDescriptor) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Меню")
                .font(.headline)

            if items.isEmpty {
                Text("Пункты меню появятся здесь")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Button {
                        onSelectItem(item)
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .opacity(item.isEnabled ? 1 : 0.45)
                }
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: onReset) {
                Label("Обнулить", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.sideMenuBackground)
    }
}
