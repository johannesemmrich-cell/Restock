import SwiftUI
import SwiftData
import Charts

struct PriceOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PurchaseRecord.date, order: .reverse) private var allRecords: [PurchaseRecord]
    @Query(filter: #Predicate<ShoppingItem> { !$0.isCompleted }) private var pendingItems: [ShoppingItem]

    @State private var expandedStoreKeys: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                receiptsSections
                spendingHistorySections
            }
            .navigationTitle("Ausgaben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Fertig").toolbarChip(prominent: true) }
                        .buttonStyle(.plain)
                        .fontWeight(.semibold)
                }
            }
}
        .devFeedback(context: "Preisübersicht")
    }

    // MARK: - Receipts (Kassenbons)

    @ViewBuilder
    private var receiptsSections: some View {
        Section {
            ContentUnavailableView(
                "Kassenbons",
                systemImage: "doc.text.viewfinder",
                description: Text("Scanne Kassenbons direkt in der Einkaufsliste eines Ladens (Kamera-Symbol oben rechts).")
            )
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Spending History

    private struct EntryDetail: Identifiable {
        let id: UUID
        let itemName: String
        let price: Double
        let qty: Double
        let unit: String
    }

    private struct StoreDetail {
        let name: String
        let total: Double
        let entries: [EntryDetail]
    }

    private struct MonthData: Identifiable {
        let id: String  // "2026-05"
        let label: String
        let total: Double
        let byStore: [StoreDetail]
    }

    private var spendingByMonth: [MonthData] {
        let withPrice = allRecords.filter { ($0.actualPrice ?? 0) > 0 }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"

        var grouped: [String: (label: String, byStore: [String: [PurchaseRecord]])] = [:]

        for record in withPrice {
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            guard let year = comps.year, let month = comps.month else { continue }
            let key = "\(year)-\(String(format: "%02d", month))"
            let label = formatter.string(from: record.date)
            let storeName = record.storeName.isEmpty ? "Unbekannt" : record.storeName

            if grouped[key] == nil { grouped[key] = (label: label, byStore: [:]) }
            grouped[key]!.byStore[storeName, default: []].append(record)
        }

        return grouped.map { (key, data) -> MonthData in
            let stores = data.byStore.map { (storeName, records) -> StoreDetail in
                let entries = records
                    .sorted { $0.date > $1.date }
                    .map { EntryDetail(id: $0.id, itemName: $0.itemName, price: $0.actualPrice!, qty: $0.quantityAmount, unit: $0.unit) }
                let total = records.reduce(0.0) { $0 + ($1.actualPrice ?? 0) }
                return StoreDetail(name: storeName, total: total, entries: entries)
            }
            .sorted { $0.total > $1.total }
            let total = stores.reduce(0.0) { $0 + $1.total }
            return MonthData(id: key, label: data.label, total: total, byStore: stores)
        }
        .sorted { $0.id > $1.id }
    }

    private func deleteRecords(storeName: String, monthKey: String) {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return }
        let calendar = Calendar.current
        allRecords
            .filter { r in
                let c = calendar.dateComponents([.year, .month], from: r.date)
                return r.storeName == storeName && c.year == year && c.month == month
            }
            .forEach { context.delete($0) }
        expandedStoreKeys.remove("\(monthKey)-\(storeName)")
        Haptics.impact(.medium)
    }

    // MARK: - Budget estimate

    private var budgetEstimate: Double {
        pendingItems.compactMap { $0.estimatedLineTotal }.reduce(0, +)
    }

    private var budgetItemCount: Int {
        pendingItems.filter { $0.estimatedPrice != nil }.count
    }

    // MARK: - Trend chart data (last 6 months)

    private var trendData: [MonthData] {
        Array(spendingByMonth.prefix(6).reversed())
    }

    // MARK: - Forgotten items (≥2 purchases, last > 60 days ago)

    private struct ForgottenItem: Identifiable {
        let id: String
        let name: String
        let daysSince: Int
        let avgPrice: Double?
    }

    private var forgottenItems: [ForgottenItem] {
        let cutoff = Date().addingTimeInterval(-60 * 86_400)
        var byItem: [String: [PurchaseRecord]] = [:]
        for r in allRecords where !r.itemName.trimmingCharacters(in: .whitespaces).isEmpty {
            byItem[r.itemName.lowercased(), default: []].append(r)
        }
        return byItem.compactMap { key, recs -> ForgottenItem? in
            guard recs.count >= 2 else { return nil }
            let last = recs.max(by: { $0.date < $1.date })!
            guard last.date < cutoff else { return nil }
            let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            let prices = recs.compactMap { $0.actualPrice }.filter { $0 > 0 }
            let avgPrice = prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)
            return ForgottenItem(id: key, name: last.itemName, daysSince: days, avgPrice: avgPrice)
        }
        .sorted { $0.daysSince > $1.daysSince }
        .prefix(10)
        .map { $0 }
    }

    @ViewBuilder
    private var spendingHistorySections: some View {
        // Budget estimate card
        if budgetItemCount > 0 {
            Section("Budgetschätzung") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktueller Einkauf")
                            .font(.system(size: 14, weight: .medium))
                        Text("\(budgetItemCount) Artikel mit bekannten Preisen")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(budgetEstimate, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.accent)
                }
                .padding(.vertical, 6)
            }
        }

        // 6-month spending trend chart
        if !trendData.isEmpty {
            Section("Ausgaben (letzte 6 Monate)") {
                Chart(trendData) { month in
                    BarMark(
                        x: .value("Monat", month.label.components(separatedBy: " ").first ?? month.label),
                        y: .value("Ausgaben", month.total)
                    )
                    .foregroundStyle(Color.accent)
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(d, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }

        // Vergessene Artikel
        if !forgottenItems.isEmpty {
            Section("Schon länger nicht gekauft") {
                ForEach(forgottenItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 14))
                            Text("Vor \(item.daysSince) Tagen zuletzt gekauft")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = item.avgPrice {
                            Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }

        // Monthly breakdown
        if spendingByMonth.isEmpty {
            Section {
                ContentUnavailableView(
                    "Keine Ausgaben erfasst",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Scanne Kassenbons in der Einkaufsliste deines Supermarkts oder trage Preise manuell ein.")
                )
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(spendingByMonth) { month in
                Section {
                    ForEach(month.byStore, id: \.name) { store in
                        let storeKey = "\(month.id)-\(store.name)"
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedStoreKeys.contains(storeKey) },
                                set: {
                                    if $0 { expandedStoreKeys.insert(storeKey) }
                                    else { expandedStoreKeys.remove(storeKey) }
                                    Haptics.impact(.light)
                                }
                            )
                        ) {
                            ForEach(store.entries) { entry in
                                HStack(spacing: 6) {
                                    Text(entry.itemName)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.primary)
                                    if entry.qty != 1 || !entry.unit.isEmpty {
                                        let qtyStr = entry.qty == entry.qty.rounded() ? "\(Int(entry.qty))" : String(format: "%.1f", entry.qty)
                                        Text(entry.unit.isEmpty ? qtyStr : "\(qtyStr) \(entry.unit)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Text(entry.price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 1)
                            }
                        } label: {
                            HStack {
                                Text(store.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(store.total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteRecords(storeName: store.name, monthKey: month.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(month.label)
                        Spacer()
                        Text(month.total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                            .fontWeight(.semibold)
                            .textCase(nil)
                    }
                }
            }
        }
    }
}
