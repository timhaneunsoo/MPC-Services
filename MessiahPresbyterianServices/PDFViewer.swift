//
//  PDFViewer.swift
//

import SwiftUI
import PDFKit

struct PDFViewer: View {
    let pdfURL: URL

    var body: some View {
        PDFKitView(pdfURL: pdfURL)
    }
}

struct PDFKitView: UIViewRepresentable {
    let pdfURL: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: pdfURL)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
