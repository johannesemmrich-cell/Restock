import SwiftUI
import UIKit

/// Dev-Mode-Verwaltung für Promo-Codes (Freunde/Familie/Live-Tester Pro-Freischaltung, siehe
/// `PromoCodeService`) — Codes erzeugen, Status sehen, entziehen/reaktivieren. 1:1 aus Dresslyst
/// übernommen (`PromoCodeAdminView`), erreichbar nur über Einstellungen → Entwickler. Die Texte
/// sind wie die übrige Dev-Oberfläche in Restock deutsche Literale (nie für Endnutzer sichtbar).
struct PromoCodeAdminView: View {
    @ObservedObject private var service = PromoCodeService.shared

    @State private var generateCountText = "5"
    @State private var generateLabel = ""
    @State private var isGenerating = false
    @State private var lastGeneratedCodes: [String] = []

    var body: some View {
        List {
            Section("Codes erzeugen") {
                TextField("Notiz (z. B. Familie)", text: $generateLabel)
                HStack {
                    Text("Anzahl")
                    Spacer()
                    TextField("5", text: $generateCountText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                Button {
                    generate()
                } label: {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Label("Erzeugen", systemImage: "plus.circle")
                    }
                }
                .disabled(isGenerating || (Int(generateCountText) ?? 0) < 1)

                if let error = service.lastGenerateErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !lastGeneratedCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zuletzt erzeugt (zum Kopieren tippen)")
                            .font(.caption.weight(.semibold))
                        ForEach(lastGeneratedCodes, id: \.self) { code in
                            copyableCodeRow(code)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .listRowBackground(Color.surface)

            Section {
                if service.isLoadingList {
                    ProgressView()
                } else if service.allCodes.isEmpty {
                    Text("Noch keine Codes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.allCodes) { record in
                        codeRow(record)
                    }
                }
                if let error = service.listErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Alle Codes (\(service.allCodes.count))")
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle("Promo-Codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await service.fetchAllCodes() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await service.fetchAllCodes()
        }
    }

    /// Tippen kopiert — die Codes sind sonst nur hier lesbar, ohne Weg, sie einem Tester ohne
    /// Abtippen zu geben (aus Dresslyst übernommen).
    private func copyableCodeRow(_ code: String) -> some View {
        Button {
            UIPasteboard.general.string = code
            Haptics.success()
        } label: {
            HStack {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.ink)
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func codeRow(_ record: PromoCodeService.PromoCodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    UIPasteboard.general.string = record.code
                    Haptics.success()
                } label: {
                    HStack(spacing: 4) {
                        Text(record.code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.ink)
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                statusBadge(record.status)
            }
            if !record.label.isEmpty {
                Text(record.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let redeemedAt = record.redeemedAt {
                Text("Eingelöst \(redeemedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(record.isRevoked ? "Reaktivieren" : "Entziehen",
                   role: record.isRevoked ? .none : .destructive) {
                Task { await service.setRevoked(!record.isRevoked, code: record.code) }
            }
            .tint(record.isRevoked ? .accent : .red)
        }
    }

    private func statusBadge(_ status: PromoCodeService.PromoCodeRecord.Status) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .open: return ("offen", .secondary)
            case .redeemed: return ("eingelöst", .accent)
            case .revoked: return ("entzogen", .red)
            }
        }()
        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func generate() {
        guard let count = Int(generateCountText), count >= 1 else { return }
        isGenerating = true
        Task {
            lastGeneratedCodes = await service.generateCodes(count: min(count, 100), label: generateLabel)
            isGenerating = false
            Haptics.success()
        }
    }
}
