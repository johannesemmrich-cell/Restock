import SwiftUI
import CloudKit

// MARK: - Share Sheet (owner shares a store)

struct StoreShareSheet: View {
    @Bindable var store: Store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isPublishing = false
    @State private var error: String?
    @State private var copied = false

    private var displayCode: String {
        guard let id = store.shareID, id.count == 6 else { return "" }
        return "\(id.prefix(3))-\(id.dropFirst(3))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("\(store.emoji) \(store.name) teilen")
                        .font(.title2.bold())
                    Text("Schick den Code per iMessage oder WhatsApp. Die andere Person gibt ihn in SmartCart ein.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if store.shareID != nil {
                    VStack(spacing: 20) {
                        Text(displayCode)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .kerning(2)

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = displayCode
                                Haptics.success()
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                            } label: {
                                Label(copied ? "Kopiert!" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .animation(.easeInOut, value: copied)

                            ShareLink(item: "Ich teile meinen SmartCart-Einkauf mit dir!\nCode: \(displayCode)") {
                                Label("Teilen", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal, 32)

                        Button(role: .destructive) {
                            store.shareID = nil
                            store.isSharedByMe = false
                            try? context.save()
                            dismiss()
                        } label: {
                            Text("Teilen beenden")
                                .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }
                } else {
                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button {
                        Task { await startSharing() }
                    } label: {
                        if isPublishing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Code generieren")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 32)
                    .disabled(isPublishing)
                }

                Spacer()
            }
            .navigationTitle("Store teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func startSharing() async {
        isPublishing = true
        error = nil
        #if DEBUG
        // Für Screenshot-Automation: Code lokal generieren statt über CloudKit zu
        // veröffentlichen (Simulator hat i.d.R. keinen angemeldeten iCloud-Account).
        if ProcessInfo.processInfo.arguments.contains("-skipCloudKitForScreenshots") {
            await MainActor.run {
                store.shareID = SharedStoreService.generateCode()
                store.isSharedByMe = true
                try? context.save()
                isPublishing = false
            }
            return
        }
        #endif
        do {
            let code = try await SharedStoreService.shared.publish(store: store)
            await MainActor.run {
                store.shareID = code
                store.isSharedByMe = true
                try? context.save()
                isPublishing = false
            }
        } catch {
            await MainActor.run {
                let ns = error as NSError
                var detail = "Fehler: \(ns.localizedDescription) (domain: \(ns.domain), code: \(ns.code))"
                if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                    detail += " | underlying: \(underlying.domain) \(underlying.code) \(underlying.localizedDescription)"
                }
                if let ckPartial = ns.userInfo[CKPartialErrorsByItemIDKey] {
                    detail += " | partial: \(ckPartial)"
                }
                self.error = detail
                print("[SharedStoreService] publish failed: \(ns) userInfo: \(ns.userInfo)")
                isPublishing = false
            }
        }
    }
}

// MARK: - Join Sheet (recipient enters a code)

struct JoinStoreSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var preview: SharedStorePreview?
    @State private var isLooking = false
    @State private var isJoining = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Store beitreten")
                        .font(.title2.bold())
                    Text("Gib den 6-stelligen Code ein, den dir jemand geschickt hat.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                TextField("Z.B. KRT-M4X", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                    .onChange(of: code) { _, new in
                        let cleaned = new.replacingOccurrences(of: "-", with: "")
                                         .replacingOccurrences(of: " ", with: "")
                                         .uppercased()
                        if cleaned != new { code = cleaned }
                        preview = nil
                        error = nil
                        if cleaned.count == 6 {
                            Task { await lookup(cleaned) }
                        }
                    }

                if isLooking {
                    ProgressView()
                } else if let preview {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            Text(preview.storeEmoji)
                                .font(.system(size: 44))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preview.storeName)
                                    .font(.headline)
                                Text("Von \(preview.ownerDevice)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 32)

                        Button {
                            Task { await join(preview) }
                        } label: {
                            if isJoining {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("\(preview.storeEmoji) \(preview.storeName) hinzufügen")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 32)
                        .disabled(isJoining)
                    }
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Beitreten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func lookup(_ shareID: String) async {
        isLooking = true
        error = nil
        do {
            let p = try await SharedStoreService.shared.fetchPreview(shareID: shareID)
            await MainActor.run { preview = p; isLooking = false }
        } catch {
            await MainActor.run {
                self.error = "Kein Store mit diesem Code gefunden."
                isLooking = false
            }
        }
    }

    private func join(_ preview: SharedStorePreview) async {
        isJoining = true
        do {
            let result = try await SharedStoreService.shared.pull(shareID: preview.shareID)
            let items = result?.items ?? []

            await MainActor.run {
                let store = Store(
                    name: preview.storeName,
                    emoji: preview.storeEmoji,
                    colorHex: preview.storeColorHex
                )
                store.shareID = preview.shareID
                store.isSharedByMe = false
                context.insert(store)

                for remote in items {
                    let item = ShoppingItem(
                        name: remote.name,
                        category: remote.category,
                        quantity: remote.quantity,
                        quantityAmount: remote.quantityAmount,
                        unit: remote.unit,
                        note: remote.note,
                        store: store
                    )
                    item.id = remote.id
                    item.isCompleted = remote.isCompleted
                    item.isUrgent = remote.isUrgent
                    context.insert(item)
                }

                try? context.save()
                isJoining = false
                dismiss()
                Task { await SharedStoreService.shared.markSynced(shareID: preview.shareID) }
            }
        } catch {
            await MainActor.run {
                self.error = "Fehler: \(error.localizedDescription)"
                isJoining = false
            }
        }
    }
}
