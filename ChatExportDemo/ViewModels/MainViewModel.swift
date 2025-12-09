//
//  MainViewModel.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import Foundation
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var isProcessing = false
    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String?

    private let ocrService = OCRService()
    private let deduplicator = MessageDeduplicator()
    private let exportService = ExportService()

    func runOCR() {
        guard !selectedImages.isEmpty else { return }
        isProcessing = true
        errorMessage = nil

        ocrService.recognizeText(in: selectedImages) { [weak self] blocks in
            guard let self else { return }
            Task { @MainActor in
                self.isProcessing = false
                self.messages = self.deduplicator.buildMessages(from: blocks)
            }
        }
    }

    func exportPlainText() -> String {
        exportService.makePlainText(from: messages)
    }

    func exportCSV() -> String {
        exportService.makeCSV(from: messages)
    }
    
    func exportPDF() -> URL? {
        exportService.makePDF(from: messages)
    }

}
