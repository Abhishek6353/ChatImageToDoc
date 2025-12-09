//
//  ExportService.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.

import Foundation
import UIKit

final class ExportService {

    // MARK: - TXT

    func makePlainText(from messages: [ChatMessage]) -> String {
        messages.enumerated().map { index, msg in
            "\(index + 1). \(msg.text)"
        }.joined(separator: "\n")
    }

    // MARK: - CSV

    func makeCSV(from messages: [ChatMessage]) -> String {
        var rows = ["index,page,text"]
        for (i, msg) in messages.enumerated() {
            let escaped = msg.text
                .replacingOccurrences(of: "\"", with: "\"\"")
            rows.append("\(i + 1),\(msg.pageIndex),\"\(escaped)\"")
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - PDF

    /// Creates a chat transcript PDF and writes it to a temporary file.
    /// - Returns: URL of the written PDF, or nil on error.
    func makePDF(from messages: [ChatMessage],
                 fileName: String = "ChatExport.pdf") -> URL? {

        let pageWidth: CGFloat  = 612   // 8.5" * 72
        let pageHeight: CGFloat = 792   // 11"  * 72
        let margin: CGFloat     = 32
        let contentWidth        = pageWidth - margin * 2

        let pdfMeta: [String: Any] = [
            kCGPDFContextTitle as String: "Chat Export",
            kCGPDFContextCreator as String: "ChatExportDemo"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMeta

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var currentY = margin

            func addPageIfNeeded(for height: CGFloat) {
                if currentY + height > pageHeight - margin {
                    ctx.beginPage()
                    currentY = margin
                }
            }

            // Paragraph styles
            let dateStyle: NSMutableParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                p.lineBreakMode = .byWordWrapping
                return p
            }()

            let leftStyle: NSMutableParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.alignment = .left
                p.lineBreakMode = .byWordWrapping
                return p
            }()

            let rightStyle: NSMutableParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.alignment = .right
                p.lineBreakMode = .byWordWrapping
                return p
            }()

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .paragraphStyle: dateStyle
            ]

            let incomingAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .paragraphStyle: leftStyle
            ]

            let outgoingAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .paragraphStyle: rightStyle
            ]

            for msg in messages {
                let text: String
                let attrs: [NSAttributedString.Key: Any]

                switch msg.kind {
                case .dateHeader:
                    text = msg.text
                    attrs = dateAttrs

                case .message:
                    let timePrefix = msg.timeText.map { "[\($0)] " } ?? ""
                    let sidePrefix = (msg.isOutgoing ?? false) ? "You: " : ""
                    text = timePrefix + sidePrefix + msg.text
                    attrs = (msg.isOutgoing ?? false) ? outgoingAttrs : incomingAttrs
                }

                let attributed = NSAttributedString(string: text, attributes: attrs)

                let bounding = attributed.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )

                let height = ceil(bounding.height)
                addPageIfNeeded(for: height)

                let drawRect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
                attributed.draw(in: drawRect)

                currentY += height + 8
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to write PDF:", error)
            return nil
        }
    }
}
