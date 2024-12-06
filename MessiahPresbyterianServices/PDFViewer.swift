import SwiftUI
import PDFKit

struct PDFViewer: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss // Dismiss the fullScreenCover
    @State private var isToolbarVisible = true // Track toolbar visibility

    var body: some View {
        NavigationView {
            ZStack {
                // PDF View
                PDFKitView(pdfURL: pdfURL)
                    .onTapGesture {
                        toggleToolbar() // Toggle toolbar visibility
                    }

                // Additional UI if needed
                if isToolbarVisible {
                    VStack {
                        Spacer() // Placeholder for any additional UI
                    }
                    .transition(.move(edge: .top))
                    .animation(.easeInOut(duration: 0.3), value: isToolbarVisible)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isToolbarVisible {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss() // Close the view
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .onAppear {
            autoHideToolbar() // Auto-hide toolbar after a delay
        }
    }

    // Toggle toolbar visibility
    private func toggleToolbar() {
        isToolbarVisible.toggle()
        if isToolbarVisible {
            autoHideToolbar() // Restart auto-hide timer when toolbar becomes visible
        }
    }

    // Automatically hide the toolbar after a delay
    private func autoHideToolbar() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                isToolbarVisible = false
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let pdfURL: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true // Fit pages to the view
        pdfView.displayMode = .singlePageContinuous // Enable smooth scrolling
        pdfView.displayDirection = .vertical // Vertical scrolling
        pdfView.document = PDFDocument(url: pdfURL)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
