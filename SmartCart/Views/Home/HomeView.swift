import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]
    @Environment(\.modelContext) private var context

    @State private var showAddItem = false
    @State private var showRecipeImport = false
    @State private var showSettings = false
    @State private var addItemText = ""
    @State private var dueSoonItems: [ConsumptionPattern] = []
    @State private var headerScale: CGFloat = 1.0

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var totalPending: Int { activeStores.reduce(0) { $0 + $1.pendingItems.count } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    quickAddBar
                    if !dueSoonItems.isEmpty { replenishmentBanner }
                    storeSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddItem)       { AddItemView() }
            .sheet(isPresented: $showRecipeImport)  { RecipeImportView() }
            .sheet(isPresented: $showSettings)      { SettingsView() }
            .onAppear { refreshDueSoon() }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient.brand)
                .frame(maxWidth: .infinity)
                .frame(height: 130)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: 210, y: -30)

            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 90, height: 90)
                .offset(x: 260, y: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("SmartCart")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                if totalPending > 0 {
                    Text(String(format: String(localized: "home.header.items"), totalPending, activeStores.count))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text(String(localized: "home.header.empty"))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
        }
        .shadow(color: Color.brand.opacity(0.4), radius: 16, x: 0, y: 6)
    }

    // MARK: - Quick add

    private var parsedHint: String? { QuickAddParser.hint(for: addItemText) }

    private var quickAddBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 18))

                    TextField(String(localized: "home.quickadd.placeholder"), text: $addItemText)
                        .submitLabel(.done)
                        .onSubmit { quickAdd() }

                    if !addItemText.isEmpty {
                        Button { addItemText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                Button {
                    Haptics.impact(.light)
                    showRecipeImport = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(LinearGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            // Smart parsing hint
            if let hint = parsedHint {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: parsedHint)
    }

    // MARK: - Replenishment banner

    private var replenishmentBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "home.replenish.title"), systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button(String(localized: "home.replenish.addall")) {
                    addDueSoonToList()
                    Haptics.success()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            }

            ForEach(dueSoonItems, id: \.itemName) { pattern in
                HStack(spacing: 8) {
                    Circle()
                        .fill(pattern.isOverdue ? Color.destructive : Color.warning)
                        .frame(width: 7, height: 7)
                    Text(pattern.itemName)
                        .font(.system(size: 14))
                    Spacer()
                    Text(pattern.isOverdue
                         ? String(localized: "replenish.overdue")
                         : String(format: String(localized: "replenish.in.days"), pattern.daysUntilNeeded))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.warning.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Store grid

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "home.stores.title"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }

            if activeStores.isEmpty {
                emptyStoresView
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activeStores) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            StoreCard(store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyStoresView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 44))
                .foregroundStyle(Color.brand.opacity(0.5))
            Text(String(localized: "home.stores.empty.title"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Button(String(localized: "home.stores.setup")) {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .cardStyle()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .foregroundStyle(.primary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Haptics.impact(.light)
                showAddItem = true
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Logic

    private func quickAdd() {
        let trimmed = addItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Haptics.impact(.light)
        let parsed = QuickAddParser.parse(trimmed)
        let category = AssignmentService.category(for: parsed.name)
        let store = AssignmentService.assign(itemName: parsed.name, to: activeStores)
        context.insert(ShoppingItem(
            name: parsed.name,
            category: category,
            quantity: parsed.quantity,
            quantityAmount: parsed.quantityAmount,
            unit: parsed.unit,
            store: store
        ))
        addItemText = ""
    }

    private func refreshDueSoon() {
        dueSoonItems = HabitService.dueSoonItems(allRecords: allRecords)
        HabitService.scheduleReplenishmentNotifications(patterns: dueSoonItems)
    }

    private func addDueSoonToList() {
        for pattern in dueSoonItems {
            let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores)
            context.insert(ShoppingItem(name: pattern.itemName, store: store))
        }
        dueSoonItems = []
    }
}
