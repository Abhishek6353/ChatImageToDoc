//
//  MessageDeduplicator.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

//import Foundation
//final class MessageDeduplicator {
//    func buildMessages(from blocks: [OCRTextBlock]) -> [ChatMessage] {
//        // Sort by page then vertical position (higher y = lower on screen)
//        let sorted = blocks.sorted {
//            if $0.pageIndex == $1.pageIndex {
//                return $0.boundingBox.midY > $1.boundingBox.midY
//            }
//            return $0.pageIndex < $1.pageIndex
//        }
//
//        var seen = Set<String>()
//        var messages: [ChatMessage] = []
//
//        for block in sorted {
//            let normalized = normalize(text: block.text)
//            guard !normalized.isEmpty else { continue }
//            if seen.contains(normalized) { continue }
//
//            seen.insert(normalized)
//
//            let orderKey = Double(block.pageIndex) + Double(1.0 - block.boundingBox.midY)
//            let msg = ChatMessage(
//                text: normalized,
//                pageIndex: block.pageIndex,
//                orderKey: orderKey
//            )
//            messages.append(msg)
//        }
//
//        return messages.sorted { $0.orderKey < $1.orderKey }
//    }
//
//    private func normalize(text: String) -> String {
//        text
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
//    }
//}


import Foundation
import CoreGraphics

final class MessageDeduplicator {

    // MARK: - Public

    func buildMessages(from blocks: [OCRTextBlock]) -> [ChatMessage] {
        // 1. Filter to screen area where chat is
        let classifiedBlocks: [ClassifiedBlock] = blocks.enumerated().compactMap { (index, block) in
            let y = block.boundingBox.midY
            // ignore status bar / title / bottom input bar
            guard y > 0.18 && y < 0.92 else { return nil }
            return ClassifiedBlock(globalIndex: index, block: block)
        }

        // 2. Classify into date headers, times, message lines
        var messageLines: [ClassifiedBlock] = []
        var timeBlocks: [ClassifiedBlock] = []
        var dateBlocks: [ClassifiedBlock] = []

        for var cb in classifiedBlocks {
            guard let normalized = basicNormalize(text: cb.block.text) else { continue }

            if isDateHeader(text: normalized) {
                cb.normalizedText = normalized
                dateBlocks.append(cb)
            } else if isTimeOnly(normalized) {
                cb.normalizedText = normalizeTimeText(normalized)
                timeBlocks.append(cb)
            } else {
                cb.normalizedText = normalized
                messageLines.append(cb)
            }
        }

        // 3. Create "bubble candidates" by grouping lines on same side/page that are very close
        let bubbles = buildBubbles(from: messageLines)

        // 4. Attach times to nearest bubble (same page)
        let bubbleTimeMap = attachTimesToBubbles(bubbles: bubbles, times: timeBlocks)

        // 5. Build ChatMessage list (date headers + bubbles)
        var seen = Set<String>()
        var result: [ChatMessage] = []

        // date headers
        for d in dateBlocks {
            let text = d.normalizedText ?? d.block.text
            let key = "H|\(text)"
            if seen.contains(key) { continue }
            seen.insert(key)

            let orderKey = orderKeyFor(block: d.block)

            result.append(
                ChatMessage(
                    kind: .dateHeader,
                    text: text,
                    timeText: nil,
                    isOutgoing: nil,
                    pageIndex: d.block.pageIndex,
                    orderKey: orderKey
                )
            )
        }

        // message bubbles
        for (index, bubble) in bubbles.enumerated() {
            let text = bubble.lines
                .compactMap { $0.normalizedText }
                .joined(separator: "\n")

            guard !text.isEmpty else { continue }

            let timeText = bubbleTimeMap[index]

            let key = "M|\(bubble.isOutgoing ? "O" : "I")|\(text)|\(timeText ?? "")"
            if seen.contains(key) { continue }
            seen.insert(key)

            result.append(
                ChatMessage(
                    kind: .message,
                    text: text,
                    timeText: timeText,
                    isOutgoing: bubble.isOutgoing,
                    pageIndex: bubble.pageIndex,
                    orderKey: bubble.orderKey
                )
            )
        }

        // 6. Sort + post-process (propagate times to nearby bubbles on same side)
        let sorted = result.sorted { $0.orderKey < $1.orderKey }
        return postProcess(sorted)
    }

    // MARK: - Internal types

    private struct ClassifiedBlock {
        let globalIndex: Int
        let block: OCRTextBlock
        var normalizedText: String?

        var midX: CGFloat { block.boundingBox.midX }
        var midY: CGFloat { block.boundingBox.midY }
        var pageIndex: Int { block.pageIndex }
    }

    private struct Bubble {
        let pageIndex: Int
        let isOutgoing: Bool
        var lines: [ClassifiedBlock]
        var minY: CGFloat
        var maxY: CGFloat
        var midX: CGFloat

        var orderKey: Double {
            Double(pageIndex) + Double(1.0 - (minY + maxY) / 2.0)
        }
    }

    // MARK: - Bubble building

    private func buildBubbles(from lines: [ClassifiedBlock]) -> [Bubble] {
        // sort top -> bottom by page, then Y
        let sorted = lines.sorted {
            if $0.pageIndex == $1.pageIndex {
                return $0.midY > $1.midY  // higher on screen first
            }
            return $0.pageIndex < $1.pageIndex
        }

        var bubbles: [Bubble] = []

        for line in sorted {
            let isOutgoing = line.midX > 0.5

            // find last bubble on same page & side to try merging into
            if let idx = bubbles.lastIndex(where: {
                $0.pageIndex == line.pageIndex && $0.isOutgoing == isOutgoing
            }) {
                let candidate = bubbles[idx]
                if canMerge(candidate: candidate, with: line) {
                    var updated = candidate
                    updated.lines.append(line)
                    updated.minY = min(updated.minY, line.midY)
                    updated.maxY = max(updated.maxY, line.midY)
                    // smooth X
                    updated.midX = (updated.midX * CGFloat(updated.lines.count - 1) + line.midX) / CGFloat(updated.lines.count)
                    bubbles[idx] = updated
                    continue
                }
            }

            // start a new bubble
            let bubble = Bubble(
                pageIndex: line.pageIndex,
                isOutgoing: isOutgoing,
                lines: [line],
                minY: line.midY,
                maxY: line.midY,
                midX: line.midX
            )
            bubbles.append(bubble)
        }

        return bubbles
    }

    private func canMerge(candidate: Bubble, with line: ClassifiedBlock) -> Bool {
        // same page & side already checked
        let dy = abs(candidate.maxY - line.midY)
        let dx = abs(candidate.midX - line.midX)

        // lines inside same bubble are usually very close vertically
        // and roughly aligned horizontally
        return dy < 0.08 && dx < 0.25
    }

    // MARK: - Time attachment

    private func attachTimesToBubbles(
        bubbles: [Bubble],
        times: [ClassifiedBlock]
    ) -> [Int: String] {
        guard !bubbles.isEmpty, !times.isEmpty else { return [:] }

        var map: [Int: String] = [:]

        for timeBlock in times {
            let timeText = timeBlock.normalizedText ?? timeBlock.block.text
            guard !timeText.isEmpty else { continue }

            let tY = timeBlock.midY
            let tX = timeBlock.midX

            var bestIndex: Int?
            var bestScore = Double.greatestFiniteMagnitude

            for (idx, bubble) in bubbles.enumerated() {
                guard bubble.pageIndex == timeBlock.pageIndex else { continue }

                let bubbleCenterY = (bubble.minY + bubble.maxY) / 2.0
                let dy = Double(abs(bubbleCenterY - tY))
                let dx = Double(abs(bubble.midX - tX))

                // prefer nearby vertically; horizontally, times are slightly to the right
                let score = dy + dx

                if score < bestScore {
                    bestScore = score
                    bestIndex = idx
                }
            }

            if let idx = bestIndex, bestScore < 0.6 {
                map[idx] = timeText
            }
        }

        return map
    }

    // MARK: - Post-processing: propagate times to close bubbles

    private struct SideKey: Hashable {
        let pageIndex: Int
        let isOutgoing: Bool
    }

    private func postProcess(_ messages: [ChatMessage]) -> [ChatMessage] {
        var output: [ChatMessage] = []
        var lastTimeForSide: [SideKey: (String, Double)] = [:]

        for var msg in messages {
            guard msg.kind == .message else {
                output.append(msg)
                continue
            }

            let side = SideKey(pageIndex: msg.pageIndex, isOutgoing: msg.isOutgoing ?? false)

            if let time = msg.timeText {
                lastTimeForSide[side] = (time, msg.orderKey)
            } else if let (lastTime, lastOrder) = lastTimeForSide[side],
                      msg.orderKey - lastOrder < 0.5 {
                // bubble very close below previous time on same side → reuse time
                msg.timeText = lastTime
            }

            // merge extremely close message bubbles (safety for any remaining split)
            if var last = output.last,
               last.kind == .message,
               last.isOutgoing == msg.isOutgoing,
               last.pageIndex == msg.pageIndex,
               abs(last.orderKey - msg.orderKey) < 0.12 {

                last.text = last.text + "\n" + msg.text
                last.timeText = msg.timeText ?? last.timeText
                output[output.count - 1] = last
            } else {
                output.append(msg)
            }
        }

        return output
    }

    // MARK: - Generic helpers

    private func orderKeyFor(block: OCRTextBlock) -> Double {
        Double(block.pageIndex) + Double(1.0 - block.boundingBox.midY)
    }

    private func basicNormalize(text: String) -> String? {
        let t = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !t.isEmpty else { return nil }

        // obvious UI noise
        let lower = t.lowercased()
        if lower == "+" || lower == "export" { return nil }

        return t
    }

    // --- Date headers ---

    private lazy var dateHeaderRegex: NSRegularExpression? = {
        // "28 Nov 2025 at 9:44 PM" or "Fri, 28 Nov"
        let pattern = #"^([A-Za-z]{3},\s*)?\d{1,2}\s+[A-Za-z]{3}(\s+\d{4})?(\s+at\s+\d{1,2}:\d{2}\s*(AM|PM)?)?$"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private func isDateHeader(text: String) -> Bool {
        guard let regex = dateHeaderRegex else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    // --- Time-only detection ---

    private lazy var timeOnlyRegex: NSRegularExpression? = {
        // "4:21 PM", "4:21PM", "21:05", "9:45PM J/", "9:45 PM JJ"
        let pattern = #"^\s*\d{1,2}:\d{2}\s*(AM|PM)?(\s*[A-Z/]{1,3})?\s*$"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private func isTimeOnly(_ text: String) -> Bool {
        guard let regex = timeOnlyRegex else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private func normalizeTimeText(_ text: String) -> String {
        // "1:04 PM J/" -> "1:04 PM"
        let comps = text.split(separator: " ").map(String.init)
        guard !comps.isEmpty else { return text }

        if comps.count >= 2,
           comps[1].uppercased() == "AM" || comps[1].uppercased() == "PM" {
            return comps[0] + " " + comps[1]
        }
        return comps[0]
    }
}
