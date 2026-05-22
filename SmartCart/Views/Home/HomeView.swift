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

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    quickAddBar
                    if !dueSoonItems.isEmpty {
                        replenishmentBanner
                    }
                    storeGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.subtleBackground)
            .navigationTitle("SmartCart")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showRecipeImport = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showRecipeImport) {
                RecipeImportView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                refreshDueSoon()
            }
        }
    }

    // MARK: - Quick add bar

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
                TextField(String(localized: "home.quickadd.placeholder"), text: $addItemText)
                    .submitLabel(.done)
                    .onSubmit { quickAdd() }
                if !addItemText.isEmpty {
                    Button {
                        addItemText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)

            Button {
                showAddItem = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Replenishment banner

    private var replenishmentBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.orange)
                Text(String(localized: "home.replenish.title"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(String(localized: "home.replenish.addall")) {
                    addDueSoonToList()
                }
                .font(.system(size: 13))
                .foregroundStyle(.blue)
            }
            ForEach(dueSoonItems, id: \.itemName) { pattern in
                HStack {
                    Circle()
                        .fill(pattern.isOverdue ? Color.red : Color.orange)
                        .frame(width: 6, height: 6)
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
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Store grid

    private var storeGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.stores.title"))
                .font(.system(size: 18, weight: .semibold))

            if activeStores.isEmpty {
                emptyStoresView
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activeStores) { store in
                        NavigationLink {
                            StoreDetailView(store: store)
                        } label: {
                            StoreCard(store: store) {}
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
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
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
    }

    // MARK: - Actions

    private func quickAdd() {
        let trimmed = addItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let category = AssignmentService.category(for: trimmed)
        let store = AssignmentService.assign(itemName: trimmed, to: activeStores)
        let item = ShoppingItem(name: trimmed, category: category, store: store)
        context.insert(item)
        addItemText = ""
    }

    private func refreshDueSoon() {
        dueSoonItems = HabitService.dueSoonItems(allRecords: allRecords)
        HabitService.scheduleReplenishmentNotifications(patterns: dueSoonItems)
    }

    private func addDueSoonToList() {
        for pattern in dueSoonItems {
            let store = AssignmentService.assign(itemName: pattern.itemName, to: activeStores)
            let item = ShoppingItem(name: pattern.itemName, store: store)
            context.insert(item)
        }
        dueSoonItems = []
    }
}
