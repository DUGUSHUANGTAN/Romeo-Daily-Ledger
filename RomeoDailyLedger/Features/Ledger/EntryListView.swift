import SwiftUI

struct EntryListView: View {
    @Bindable var model: LedgerViewModel
    let theme: AppTheme
    let typography: AppTypography.Style

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if model.entries.isEmpty {
                    VStack(spacing: 6) {
                        Text("今天还没有账目").font(AppTypography.title(typography))
                        Text("在上方快速记录第一笔收支。")
                            .font(AppTypography.body(typography))
                            .foregroundStyle(theme.secondaryText.color)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                        .accessibilityIdentifier("entry-list-empty")
                }
                ForEach(model.entries) { entry in
                    Button {
                        model.toggleSelection(entry)
                    } label: {
                        HStack(spacing: 14) {
                            Text(entry.kind == .income ? "收" : "支")
                                .font(AppTypography.caption(typography))
                                .frame(width: 28, height: 28)
                                .background(theme.secondaryAccent.color.opacity(0.22), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.note.isEmpty ? "无备注" : entry.note)
                                    .font(AppTypography.body(typography))
                                Text(entry.occurredAt, format: .dateTime.hour().minute())
                                    .font(AppTypography.caption(typography))
                                    .foregroundStyle(theme.secondaryText.color)
                            }
                            Spacer()
                            Text(LedgerFormatting.amount(entry.amount))
                                .font(AppTypography.title(typography))
                        }
                        .padding(12)
                        .foregroundStyle(theme.primaryText.color)
                        .background(model.selectedEntryIDs.contains(entry.id) ? theme.primaryAccent.color.opacity(0.16) : theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.kind == .income ? "收入" : "支出") \(LedgerFormatting.amount(entry.amount)) \(entry.note)")
                    .accessibilityIdentifier("entry-row-\(entry.id.uuidString.lowercased())")
                    .simultaneousGesture(TapGesture(count: 2).onEnded { model.editingEntry = entry })
                    .contextMenu {
                        Button("编辑账目") { model.editingEntry = entry }
                    }
                }
            }
        }
        .accessibilityLabel("账目列表")
        .accessibilityIdentifier("entry-list")
    }
}
