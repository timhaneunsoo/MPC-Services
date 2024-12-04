import SwiftUI
import QuickLook

struct QuickLookPreviewWithIndicator: View {
    let fileURL: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            QuickLookPreview(fileURL: fileURL)

            VStack {
                // Indicator bar at the top
                Capsule()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 60, height: 6)
                    .padding(.top, 10)

                Spacer()
            }
        }
        .background(Color.black.opacity(0.5)) // Optional background for better visibility
        .onTapGesture {
            // Allow users to dismiss by tapping anywhere on the background
            onDismiss()
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(fileURL: fileURL)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
}
