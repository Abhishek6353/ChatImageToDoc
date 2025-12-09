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

    // MARK: - WhatsApp-style PDF (bubble layout)

    func makePDF(from messages: [ChatMessage],
                 fileName: String = "ChatExport.pdf") -> URL? {

        let pageWidth: CGFloat  = 612    // 8.5 * 72
        let pageHeight: CGFloat = 792    // 11  * 72
        let margin: CGFloat     = 24
        let contentWidth        = pageWidth - margin * 2

        let bubbleMaxWidth      = contentWidth * 0.72
        let bubblePaddingX: CGFloat = 10
        let bubblePaddingY: CGFloat = 6
        let verticalSpacing: CGFloat = 8

        let meta: [String: Any] = [
            kCGPDFContextTitle as String: "Chat Export",
            kCGPDFContextCreator as String: "ChatExportDemo"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            var currentY = margin

            func beginNewPage() {
                ctx.beginPage()
                currentY = margin
            }

            func ensureSpace(for height: CGFloat) {
                if currentY + height > pageHeight - margin {
                    beginNewPage()
                }
            }

            // Fonts
            let messageFont = UIFont.systemFont(ofSize: 13)
            let timeFont    = UIFont.systemFont(ofSize: 11)
            let dateFont    = UIFont.systemFont(ofSize: 11, weight: .semibold)

            // Paragraph styles
            let bubbleParagraph: NSMutableParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.alignment = .left
                p.lineBreakMode = .byWordWrapping
                return p
            }()

            let dateParagraph: NSMutableParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                p.lineBreakMode = .byWordWrapping
                return p
            }()

            // Colors
            let outgoingColor = UIColor.systemBlue
            let incomingColor = UIColor(white: 0.85, alpha: 1.0)
            let datePillColor = UIColor(white: 0.9, alpha: 1.0)
            let textColorDark = UIColor.black
            let textColorLight = UIColor.white

            // White page background
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

            for msg in messages {
                switch msg.kind {

                case .dateHeader:
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: dateFont,
                        .paragraphStyle: dateParagraph,
                        .foregroundColor: UIColor.darkGray
                    ]
                    let attributed = NSAttributedString(string: msg.text, attributes: attrs)
                    let maxSize = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
                    var rect = attributed.boundingRect(
                        with: maxSize,
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    rect.size.width = ceil(rect.width) + 16
                    rect.size.height = ceil(rect.height) + 4

                    ensureSpace(for: rect.height + verticalSpacing * 2)

                    let pillX = (pageWidth - rect.width) / 2
                    let pillRect = CGRect(x: pillX,
                                          y: currentY,
                                          width: rect.width,
                                          height: rect.height)

                    // pill background
                    let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillRect.height / 2)
                    ctx.cgContext.setFillColor(datePillColor.cgColor)
                    ctx.cgContext.addPath(pillPath.cgPath)
                    ctx.cgContext.fillPath()

                    // text
                    let textRect = pillRect.insetBy(dx: 8, dy: 2)
                    attributed.draw(in: textRect)

                    currentY += pillRect.height + verticalSpacing

                case .message:
                    let isOutgoing = msg.isOutgoing ?? false
                    let bubbleColor = isOutgoing ? outgoingColor : incomingColor
                    let textColor = isOutgoing ? textColorLight : textColorDark

                    let paragraph = bubbleParagraph
                    let attrsText: [NSAttributedString.Key: Any] = [
                        .font: messageFont,
                        .paragraphStyle: paragraph,
                        .foregroundColor: textColor
                    ]

                    let attrsTime: [NSAttributedString.Key: Any] = [
                        .font: timeFont,
                        .paragraphStyle: paragraph,
                        .foregroundColor: textColor.withAlphaComponent(0.8)
                    ]

                    let textAttr = NSAttributedString(
                        string: msg.text,
                        attributes: attrsText
                    )

                    let textMaxWidth = bubbleMaxWidth - bubblePaddingX * 2
                    let textBounds = textAttr.boundingRect(
                        with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    var textHeight = ceil(textBounds.height)
                    var bubbleWidth = ceil(textBounds.width) + bubblePaddingX * 2

                    var timeHeight: CGFloat = 0
                    var timeSize = CGSize.zero
                    if let t = msg.timeText, !t.isEmpty {
                        let timeAttr = NSAttributedString(string: t, attributes: attrsTime)
                        let timeBounds = timeAttr.boundingRect(
                            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )
                        timeHeight = ceil(timeBounds.height)
                        timeSize = CGSize(width: ceil(timeBounds.width), height: timeHeight)

                        // ensure bubble wide enough to host time at bottom-right
                        bubbleWidth = max(bubbleWidth, timeSize.width + bubblePaddingX * 2)
                    }

                    if bubbleWidth > bubbleMaxWidth {
                        bubbleWidth = bubbleMaxWidth
                    }

                    let bubbleHeight = textHeight + (timeHeight > 0 ? timeHeight + 2 : 0) + bubblePaddingY * 2

                    ensureSpace(for: bubbleHeight + verticalSpacing)

                    let bubbleX: CGFloat
                    if isOutgoing {
                        bubbleX = pageWidth - margin - bubbleWidth
                    } else {
                        bubbleX = margin
                    }
                    let bubbleRect = CGRect(x: bubbleX,
                                            y: currentY,
                                            width: bubbleWidth,
                                            height: bubbleHeight)

                    // bubble background
                    let bubblePath = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 18)
                    ctx.cgContext.setFillColor(bubbleColor.cgColor)
                    ctx.cgContext.addPath(bubblePath.cgPath)
                    ctx.cgContext.fillPath()

                    // draw text
                    let textRect = CGRect(
                        x: bubbleRect.minX + bubblePaddingX,
                        y: bubbleRect.minY + bubblePaddingY,
                        width: bubbleRect.width - bubblePaddingX * 2,
                        height: textHeight
                    )
                    textAttr.draw(in: textRect)

                    // draw time at bottom-right inside bubble
                    if let t = msg.timeText, !t.isEmpty {
                        let timeAttr = NSAttributedString(string: t, attributes: attrsTime)
                        let timeOrigin = CGPoint(
                            x: bubbleRect.maxX - bubblePaddingX - timeSize.width,
                            y: textRect.maxY + 2
                        )
                        let timeRect = CGRect(origin: timeOrigin, size: timeSize)
                        timeAttr.draw(in: timeRect)
                    }

                    currentY += bubbleHeight + verticalSpacing
                }
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to write PDF:", error)
            return nil
        }
    }
}
