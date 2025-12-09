//
//  ChatMessage.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import Foundation

enum ChatMessageKind {
    case dateHeader      // e.g. "Fri, 28 Nov"
    case message         // actual chat bubble
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let kind: ChatMessageKind
    var text: String             // var so we can merge lines
    var timeText: String?        // "1:04 PM"
    let isOutgoing: Bool?        // nil for dateHeader
    let pageIndex: Int
    let orderKey: Double         // page + vertical position
}
