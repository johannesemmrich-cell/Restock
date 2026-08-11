import SwiftUI

/// Which picker `EditItemView`'s single `.sheet(item:)` should present. `Identifiable` so the
/// item itself (rather than two separate `Bool` bindings) is the one source of truth for "which
/// picker, if any" — avoids the SwiftUI pitfall of two sibling `.sheet(isPresented:)` modifiers
/// racing/misrouting to the wrong one.
enum ItemPhotoPickerSource: String, Identifiable {
    case camera, library
    var id: String { rawValue }
    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera: return .camera
        case .library: return .photoLibrary
        }
    }
}

/// Same camera-first/photo-library-fallback `UIImagePickerController` wrapper pattern already
/// used in `ReceiptScannerView`/`RecipeImportView`, factored out here since `EditItemView` is a
/// third call site.
struct ItemPhotoPicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ItemPhotoPicker
        init(_ parent: ItemPhotoPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            parent.completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.completion(nil)
        }
    }
}

/// Full-screen preview opened by tapping the thumbnail in `EditItemView`'s photo section.
/// Pinch-to-zoom via `MagnificationGesture` since a single item photo can be worth inspecting
/// closely (e.g. reading a label).
struct FullScreenPhotoView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in zoom = max(1, lastZoom * value) }
                        .onEnded { _ in lastZoom = zoom }
                )
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .padding()
            }
        }
    }
}
