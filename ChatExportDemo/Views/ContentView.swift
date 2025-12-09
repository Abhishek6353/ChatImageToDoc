//
//  ContentView.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showPicker = false
    @State private var showExportSheet = false
    @State private var exportText: String = ""

    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.selectedImages.isEmpty {
                    Text("No screenshots selected")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    Text("\(viewModel.selectedImages.count) screenshots selected")
                        .font(.subheadline)
                        .padding(.top, 4)
                }

                Button("Select Screenshots") {
                    showPicker = true
                }
                .padding(.vertical)

                Button("Run OCR") {
                    viewModel.runOCR()
                }
                .disabled(viewModel.selectedImages.isEmpty || viewModel.isProcessing)

                if viewModel.isProcessing {
                    ProgressView("Processing…")
                        .padding()
                }

                MessagesListView(messages: viewModel.messages)

                HStack {
                    Button("Export TXT") {
                        exportText = viewModel.exportPlainText()
                        showExportSheet = true
                    }
                    .disabled(viewModel.messages.isEmpty)

                    Button("Export CSV") {
                        exportText = viewModel.exportCSV()
                        showExportSheet = true
                    }
                    .disabled(viewModel.messages.isEmpty)

                    Button("Export PDF") {
                        pdfURL = viewModel.exportPDF()
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
                .padding(.vertical)
            }
            .padding()
            .navigationTitle("Chat OCR Demo")
        }
        .sheet(isPresented: $showPicker) {
            ScreenshotPickerView(images: $viewModel.selectedImages)
        }
        .sheet(isPresented: $showExportSheet) {
            TextEditor(text: .constant(exportText))
                .padding()
        }
        .sheet(item: $pdfURL) { url in
            ActivityView(activityItems: [url])
        }
    }
}

#Preview {
    ContentView()
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
