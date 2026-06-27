import SwiftUI
import StoreKit

// MARK: - Context

enum PaywallContext {
    case premium(feature: String)
    case sharedLists
}

// MARK: - PaywallView

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @StateObject private var premium = PremiumService.shared
    @State private var selectedPlanID = PremiumService.yearlyID
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                    switch context {
                    case .sharedLists:
                        sharedListsOptions
                    case .premium:
                        fullPremiumOptions
                    }

                    ctaSection
                        .padding(.top, 28)

                    restoreButton
                        .padding(.top, 16)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }

                    legalText
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient.brand.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: headerIcon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LinearGradient.brand)
            }

            Text(headerTitle)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)

            Text(headerSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerIcon: String {
        switch context {
        case .sharedLists: return "person.2.fill"
        case .premium: return "star.fill"
        }
    }

    private var headerTitle: String {
        switch context {
        case .sharedLists: return "Geteilte Listen"
        case .premium: return "SmartCart Pro"
        }
    }

    private var headerSubtitle: String {
        switch context {
        case .sharedLists: return "Kaufe gemeinsam mit Partner,\nFamilie oder Mitbewohnern ein."
        case .premium(let feature): return "Schalte \(feature) und alle weiteren\nPro-Features frei."
        }
    }

    // MARK: - Price helpers

    private func productPrice(for id: String) -> String {
        premium.product(for: id)?.displayPrice ?? fallbackPrice(for: id)
    }

    private func fallbackPrice(for id: String) -> String {
        switch id {
        case PremiumService.monthlyID:     return "1,99 €"
        case PremiumService.yearlyID:      return "9,99 €"
        case PremiumService.lifetimeID:    return "4,99 €"
        case PremiumService.sharedListsID: return "4,99 €"
        default: return "–"
        }
    }

    // MARK: - Full Premium Options

    private var fullPremiumOptions: some View {
        VStack(spacing: 12) {
            benefitsList

            VStack(spacing: 10) {
                planCard(
                    id: PremiumService.yearlyID,
                    title: "Jährlich",
                    price: "\(productPrice(for: PremiumService.yearlyID))/Jahr",
                    detail: "= ca. 0,83 €/Monat",
                    badge: "Beliebt"
                )
                planCard(
                    id: PremiumService.monthlyID,
                    title: "Monatlich",
                    price: "\(productPrice(for: PremiumService.monthlyID))/Monat",
                    detail: nil,
                    badge: nil
                )
                planCard(
                    id: PremiumService.lifetimeID,
                    title: "Einmalig",
                    price: productPrice(for: PremiumService.lifetimeID),
                    detail: "einmaliger Kauf",
                    badge: nil
                )
            }
        }
    }

    // MARK: - Shared Lists Options

    private var sharedListsOptions: some View {
        VStack(spacing: 12) {
            sharedListsBenefits

            VStack(spacing: 10) {
                addOnCard(
                    id: PremiumService.sharedListsID,
                    title: "Geteilte Listen Add-on",
                    price: productPrice(for: PremiumService.sharedListsID),
                    detail: "nur geteilte Listen",
                    isRecommended: false
                )

                HStack {
                    VStack { Divider() }
                    Text("oder")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                    VStack { Divider() }
                }

                addOnCard(
                    id: PremiumService.yearlyID,
                    title: "SmartCart Pro",
                    price: "\(productPrice(for: PremiumService.yearlyID))/Jahr",
                    detail: "alle Features inklusive",
                    isRecommended: true
                )
            }
        }
    }

    // MARK: - Plan Cards

    private func planCard(id: String, title: String, price: String, detail: String?, badge: String?) -> some View {
        let isSelected = selectedPlanID == id
        return Button { selectedPlanID = id } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.brand : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.brand, in: Capsule())
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(price)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.brand : .primary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.brand : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func addOnCard(id: String, title: String, price: String, detail: String, isRecommended: Bool) -> some View {
        let isSelected = selectedPlanID == id
        return Button { selectedPlanID = id } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.brand : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("Empfohlen")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.brand, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.brand : .primary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.brand : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(premiumBenefits, id: \.title) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(benefit.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(benefit.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sharedListsBenefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sharedListBenefits, id: \.title) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(benefit.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(benefit.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private struct Benefit { let icon: String; let title: String; let description: String }

    private let premiumBenefits: [Benefit] = [
        Benefit(icon: "doc.text.viewfinder",   title: "Kassenbon-Scan",        description: "Preise automatisch aus Kassenbon einlesen"),
        Benefit(icon: "fork.knife",             title: "Menüplan",              description: "Wochenspeiseplan & Zutaten automatisch hinzufügen"),
        Benefit(icon: "chart.bar.fill",         title: "Ausgaben-Analyse",      description: "Monatliche Ausgaben & Budgetschätzung"),
        Benefit(icon: "arrow.clockwise",        title: "Nachkauf-Erinnerungen", description: "Intelligente Hinweise, wenn ein Artikel fällig ist"),
        Benefit(icon: "folder.fill",            title: "Vorlagen",              description: "Listen als Vorlage speichern & wiederverwenden"),
        Benefit(icon: "leaf.fill",              title: "Saisonale Vorschläge",  description: "Saisonale Einkaufsideen passend zum Monat"),
    ]

    private let sharedListBenefits: [Benefit] = [
        Benefit(icon: "person.2.fill",      title: "Echtzeit-Sync",         description: "Änderungen erscheinen sofort bei allen Teilnehmern"),
        Benefit(icon: "person.badge.plus",  title: "Artikel zuweisen",      description: "Wer kauft was — Zuweisung per Swipe"),
        Benefit(icon: "exclamationmark.circle.fill", title: "Dringende Artikel",  description: "Markiere Artikel als dringend für alle sichtbar"),
    ]

    // MARK: - CTA

    private var ctaSection: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if premium.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(LinearGradient.brand)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(premium.isPurchasing)
    }

    private var ctaTitle: String {
        switch context {
        case .sharedLists:
            if selectedPlanID == PremiumService.sharedListsID {
                return "Add-on freischalten — \(productPrice(for: PremiumService.sharedListsID))"
            } else {
                return "Pro freischalten — \(productPrice(for: PremiumService.yearlyID))/Jahr"
            }
        case .premium:
            switch selectedPlanID {
            case PremiumService.monthlyID:
                return "Jetzt freischalten — \(productPrice(for: PremiumService.monthlyID))/Monat"
            case PremiumService.yearlyID:
                return "Jetzt freischalten — \(productPrice(for: PremiumService.yearlyID))/Jahr"
            case PremiumService.lifetimeID:
                return "Jetzt freischalten — \(productPrice(for: PremiumService.lifetimeID))"
            default:
                return "Jetzt freischalten"
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task {
                isRestoring = true
                await premium.restorePurchases()
                isRestoring = false
                if premium.isPremiumUnlocked || premium.isSharedListsUnlocked {
                    dismiss()
                }
            }
        } label: {
            Text(isRestoring ? "Wird wiederhergestellt…" : "Käufe wiederherstellen")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .disabled(isRestoring)
    }

    private var legalText: some View {
        Text("Abonnements verlängern sich automatisch. Kündigung jederzeit in den iPhone-Einstellungen möglich.")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Purchase

    private func purchase() async {
        errorMessage = nil
        guard let product = premium.product(for: selectedPlanID) else {
            // Fallback for testing without App Store Connect products
            dismiss()
            return
        }
        do {
            let success = try await premium.purchase(product)
            if success { dismiss() }
        } catch {
            errorMessage = "Kauf fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
