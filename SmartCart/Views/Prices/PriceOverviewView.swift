import SwiftUI
import SwiftData

struct PriceOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PurchaseRecord.date, order: .reverse) private var allRecords: [PurchaseRecord]

    @State private var selectedTab = 0  // 0 = Preisvergleich, 1 = Ausgaben

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $selectedTab) {
                        Text("Preisvergleich").tag(0)
                        Text("Ausgaben").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if selectedTab == 0 {
                    priceComparisonSections
                } else {
                    spendingHistorySections
                }
            }
            .navigationTitle("Preise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .devFeedback(context: "Preisübersicht")
    }

    // MARK: - Price Comparison

    private struct ItemPrices {
        let itemName: String
        var stores: [(name: String, price: Double)]

        var cheapestStore: String { stores.min(by: { $0.price < $1.price })?.name ?? "" }
        var spread: Double? {
            guard stores.count >= 2 else { return nil }
            return stores.map(\.price).max()! - stores.map(\.price).min()!
        }
    }

    private var comparisonData: [ItemPrices] {
        let withPrice = allRecords.filter { ($0.actualPrice ?? 0) > 0 && !$0.storeName.isEmpty }

        // Most recent price per (itemName, storeName)
        var grouped: [String: [String: Double]] = [:]
        for record in withPrice {
            let key = record.itemName.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if grouped[key] == nil { grouped[key] = [:] }
            // allRecords is sorted by date desc; first occurrence = most recent
            if grouped[key]![record.storeName] == nil {
                grouped[key]![record.storeName] = record.actualPrice!
            }
        }

        return grouped.map { (itemName, storeMap) -> ItemPrices in
            let stores = storeMap.map { (name: $0.key, price: $0.value) }
                .sorted { $0.price < $1.price }
            return ItemPrices(itemName: itemName.capitalized, stores: stores)
        }
        .filter { !$0.stores.isEmpty }
        .sorted { a, b in
            // Items with multiple stores first, then alphabetically
            if (a.stores.count > 1) != (b.stores.count > 1) { return a.stores.count > 1 }
            return a.itemName < b.itemName
        }
    }

    @ViewBuilder
    private var priceComparisonSections: some View {
        if comparisonData.isEmpty {
            Section {
                ContentUnavailableView(
                    "Keine Preisdaten",
                    systemImage: "tag.slash",
                    description: Text("Gib Preise beim Bearbeiten von Artikeln ein oder scanne Kassenbons in der Einkaufsliste.")
                )
                .listRowBackground(Color.clear)
            }
        } else {
            Section("Artikel (\(comparisonData.count))") {
                ForEach(comparisonData, id: \.itemName) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.itemName)
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            if let spread = item.spread {
                                Text(String(format: "Δ %.2f %@", spread, Locale.current.currencySymbol ?? "€"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(item.stores, id: \.name) { entry in
                                    let isCheapest = entry.name == item.cheapestStore

                                    VStack(spacing: 3) {
                                        Text(entry.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(isCheapest ? .green : .secondary)
                                        Text(entry.price, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                            .font(.system(size: 13, weight: isCheapest ? .semibold : .regular))
                                            .foregroundStyle(isCheapest ? .green : .primary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        isCheapest ? Color.green.opacity(0.1) : Color(.systemGray6),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isCheapest ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Spending History

    private struct MonthData: Identifiable {
        let id: String  // "2026-05"
        let label: String
        let total: Double
        let byStore: [(name: String, total: Double)]
    }

    private var spendingByMonth: [MonthData] {
        let withPrice = allRecords.filter { ($0.actualPrice ?? 0) > 0 }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"

        var grouped: [String: (label: String, byStore: [String: Double])] = [:]

        for record in withPrice {
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            guard let year = comps.year, let month = comps.month else { continue }
            let key = "\(year)-\(String(format: "%02d", month))"
            let label = formatter.string(from: record.date)

            if grouped[key] == nil { grouped[key] = (label: label, byStore: [:]) }
            let storeName = record.storeName.isEmpty ? "Unbekannt" : record.storeName
            grouped[key]!.byStore[storeName, default: 0] += record.actualPrice!
        }

        return grouped.map { (key, data) -> MonthData in
            let byStore = data.byStore.map { (name: $0.key, total: $0.value) }
                .sorted { $0.total > $1.total }
            let total = byStore.reduce(0.0) { $0 + $1.total }
            return MonthData(id: key, label: data.label, total: total, byStore: byStore)
        }
        .sorted { $0.id > $1.id }
    }

    @ViewBuilder
    private var spendingHistorySections: some View {
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
                    ForEach(month.byStore, id: \.name) { entry in
                        HStack {
                            Text(entry.name)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.total, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                                .font(.system(size: 13, weight: .medium))
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
