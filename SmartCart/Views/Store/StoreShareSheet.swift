import SwiftUI
import SwiftData
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
                    .foregroundStyle(Color.accent)

                VStack(spacing: 8) {
                    Text(String(format: String(localized: "share.title.format"), store.emoji, store.name))
                        .font(.title2.bold())
                    Text(String(localized: "share.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if store.shareID != nil {
                    VStack(spacing: 20) {
                        Text(displayCode)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.ink)
                            .kerning(2)

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = displayCode
                                Haptics.success()
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                            } label: {
                                Label(copied ? String(localized: "share.copied") : String(localized: "share.copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Color.accentContainer, in: RoundedRectangle(cornerRadius: RCRadius.control))
                            }
                            .buttonStyle(.pressable)
                            .animation(.easeInOut, value: copied)

                            ShareLink(item: String(format: String(localized: "share.sharelink.message"), displayCode)) {
                                Label(String(localized: "share.sharelabel"), systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.restockPrimary)
                        }
                        .padding(.horizontal, 32)

                        if !store.members.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(String(localized: "sharing.members.title"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                VStack(spacing: 8) {
                                    ForEach(store.members, id: \.self) { member in
                                        HStack(spacing: 10) {
                                            Image(systemName: "person.crop.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(Color.accent)
                                            Text(member)
                                                .font(.system(size: 15))
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }

                        Button(role: .destructive) {
                            if let shareID = store.shareID {
                                Task { await SharedStoreService.shared.unsubscribe(shareID: shareID) }
                            }
                            store.shareID = nil
                            store.isSharedByMe = false
                            try? context.save()
                            dismiss()
                        } label: {
                            Text(String(localized: "share.stopsharing"))
                                .font(.subheadline)
                        }
                        .buttonStyle(.pressable)
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
                                .tint(Color.onButton)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(String(localized: "share.generatecode"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.restockPrimary)
                    .padding(.horizontal, 32)
                    .disabled(isPublishing)
                }

                Spacer()
            }
            .navigationTitle(String(localized: "share.navtitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.done")).toolbarChip() }
                        .buttonStyle(.pressable)
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
            let members = try? await SharedStoreService.shared.addSelfAsMember(shareID: code)
            try? await SharedStoreService.shared.subscribe(shareID: code)
            await MainActor.run {
                store.shareID = code
                store.isSharedByMe = true
                for name in members ?? [] { store.addMember(name) }
                store.addMember(UserIdentity.displayName)
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
                    .foregroundStyle(Color.accent)

                VStack(spacing: 8) {
                    Text(String(localized: "share.join.title"))
                        .font(.title2.bold())
                    Text(String(localized: "share.join.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                TextField(String(localized: "share.join.codeplaceholder"), text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: RCRadius.control).strokeBorder(Color.hairline))
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
                                Text(String(format: String(localized: "share.join.fromdevice.format"), preview.ownerDevice))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
                        .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
                        .padding(.horizontal, 32)

                        Button {
                            Task { await join(preview) }
                        } label: {
                            if isJoining {
                                ProgressView()
                                    .tint(Color.onButton)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(String(format: String(localized: "share.join.add.format"), preview.storeEmoji, preview.storeName))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.restockPrimary)
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
            .navigationTitle(String(localized: "share.join.navtitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip() }
                        .buttonStyle(.pressable)
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
                self.error = String(localized: "share.join.notfound")
                isLooking = false
            }
        }
    }

    private func join(_ preview: SharedStorePreview) async {
        isJoining = true

        // Joining the same code twice would create a second local store with the same shareID;
        // both would then poll and push the same CKRecord and show up as confusing duplicates.
        let alreadyJoinedName: String? = await MainActor.run {
            let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
            return stores.first(where: { $0.shareID == preview.shareID })?.name
        }
        if let name = alreadyJoinedName {
            await MainActor.run {
                self.error = String(format: String(localized: "share.join.alreadyjoined.format"), name)
                isJoining = false
            }
            return
        }

        do {
            let result = try await SharedStoreService.shared.pull(shareID: preview.shareID)

            let store = Store(
                name: preview.storeName,
                emoji: preview.storeEmoji,
                colorHex: preview.storeColorHex
            )
            store.shareID = preview.shareID
            store.isSharedByMe = false

            await MainActor.run { context.insert(store) }
            // Reuses the same merge logic as the periodic sync, so joining is exactly
            // equivalent to a first pull — no separate item-copying path to maintain.
            if let result {
                await SyncCoordinator.shared.apply(items: result.items, members: result.members, deletedIDs: result.deletedIDs, prices: result.prices, priceDates: result.priceDates, modifiedAt: result.modifiedAt, to: store)
            }

            let members = try? await SharedStoreService.shared.addSelfAsMember(shareID: preview.shareID)
            try? await SharedStoreService.shared.subscribe(shareID: preview.shareID)

            await MainActor.run {
                for name in members ?? [] { store.addMember(name) }
                // Always list ourselves locally, even if the remote member write above failed —
                // the next successful push merges local members into the record anyway.
                store.addMember(UserIdentity.displayName)
                try? context.save()
                isJoining = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = String(format: String(localized: "share.join.error.format"), error.localizedDescription)
                isJoining = false
            }
        }
    }
}
