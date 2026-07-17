import SwiftUI
import SwiftData

struct RecipeImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var activeStores: [Store]

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isRecognizing = false
    @State private var recognizedIngredients: [RecognizedIngredient] = []
    @State private var selectedIngredients: Set<String> = []
    @State private var ingredientsExpanded = true
    @State private var error: String?
    /// Explizit gewählte Ziel-Liste; `nil` = "Automatisch zuordnen" (bisheriges Verhalten).
    @State private var targetStore: Store?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if recognizedIngredients.isEmpty {
                    importPrompt
                } else {
                    ingredientList
                }
            }
            .navigationTitle(String(localized: "recipe.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                if !recognizedIngredients.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "recipe.add.selected")) {
                            addSelected()
                        }
                        .disabled(selectedIngredients.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePickerView(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(image: $selectedImage, sourceType: .photoLibrary)
            }
            .onChange(of: selectedImage) { _, img in
                if let img { recognize(image: img) }
            }
            .overlay {
                if isRecognizing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(String(localized: "recipe.recognizing"))
                                .foregroundStyle(.white)
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                }
            }
        }
        .devFeedback(context: "Rezept-Import")
    }

    // MARK: - Import prompt

    private var importPrompt: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text(String(localized: "recipe.prompt.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(String(localized: "recipe.prompt.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    }
                } label: {
                    Label(String(localized: "recipe.source.camera"), systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                Button {
                    showImagePicker = true
                } label: {
                    Label(String(localized: "recipe.source.library"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Ingredient list

    private var ingredientList: some View {
        List {
            Section {
                Picker(selection: $targetStore) {
                    Text("Automatisch zuordnen").tag(nil as Store?)
                    ForEach(activeStores) { store in
                        Text("\(store.emoji) \(store.name)").tag(store as Store?)
                    }
                } label: {
                    Label("Ziel-Liste", systemImage: "list.bullet")
                        .font(.system(size: 15))
                }
                .pickerStyle(.menu)
            }

            Section {
                DisclosureGroup(isExpanded: $ingredientsExpanded) {
                    HStack {
                        Button(String(localized: "recipe.select.all")) {
                            selectedIngredients = Set(recognizedIngredients.map { $0.id.uuidString })
                        }
                        Spacer()
                        Button(String(localized: "recipe.deselect.all")) {
                            selectedIngredients.removeAll()
                        }
                    }
                    .font(.system(size: 14))

                    ForEach(recognizedIngredients) { ingredient in
                        let selected = selectedIngredients.contains(ingredient.id.uuidString)
                        HStack(spacing: 12) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selected ? .blue : Color(.systemGray3))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .font(.system(size: 15))
                                if !ingredient.quantity.isEmpty && ingredient.quantity != "1" || !ingredient.unit.isEmpty {
                                    Text("\(ingredient.quantity) \(ingredient.unit)".trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let store = resolvedStore(for: ingredient) {
                                Text(store.emoji)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected {
                                selectedIngredients.remove(ingredient.id.uuidString)
                            } else {
                                selectedIngredients.insert(ingredient.id.uuidString)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(String(localized: "recipe.ingredients.section"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(recognizedIngredients.count)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                    }
                }
            }

            Section {
                Button {
                    selectedImage = nil
                    recognizedIngredients = []
                    selectedIngredients = []
                } label: {
                    Label(String(localized: "recipe.scan.again"), systemImage: "camera")
                }
            }
        }
    }

    // MARK: - Actions

    private func recognize(image: UIImage) {
        isRecognizing = true
        error = nil
        Task {
            do {
                let results = try await RecipeRecognitionService.shared.recognizeIngredients(from: image)
                await MainActor.run {
                    recognizedIngredients = results
                    selectedIngredients = Set(results.map { $0.id.uuidString })
                    isRecognizing = false
                    if results.isEmpty {
                        error = String(localized: "recipe.error.none_found")
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isRecognizing = false
                }
            }
        }
    }

    /// Laden, den eine Zutat beim Import bekommt (auch für die Emoji-Vorschau):
    /// explizit gewählte Ziel-Liste, sonst Auto-Zuordnung mit Fallback auf den
    /// ersten aktiven Laden, damit keine Zutat ohne Liste angelegt wird.
    private func resolvedStore(for ingredient: RecognizedIngredient) -> Store? {
        if let targetStore { return targetStore }
        return AssignmentService.assign(itemName: ingredient.name, to: activeStores) ?? activeStores.first
    }

    private func addSelected() {
        let toAdd = recognizedIngredients.filter { selectedIngredients.contains($0.id.uuidString) }
        var touchedStores: [Store?] = []
        for ingredient in toAdd {
            let category = AssignmentService.category(for: ingredient.name)
            let store = resolvedStore(for: ingredient)
            let item = ShoppingItem(
                name: ingredient.name,
                category: category,
                quantity: ingredient.quantity,
                quantityAmount: Double(ingredient.quantity.replacingOccurrences(of: ",", with: ".")) ?? 1,
                unit: ingredient.unit,
                store: store
            )
            context.insert(item)
            touchedStores.append(store)
        }
        SyncCoordinator.shared.pushInBackground(touchedStores)
        dismiss()
    }
}

// MARK: - Image Picker wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
