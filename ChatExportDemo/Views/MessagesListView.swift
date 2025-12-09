//
//  MessagesListView.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import SwiftUI

struct MessagesListView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(messages) { msg in
                    switch msg.kind {
                    case .dateHeader:
                        DateHeaderView(text: msg.text)

                    case .message:
                        MessageBubbleView(
                            text: msg.text,
                            timeText: msg.timeText,
                            isOutgoing: msg.isOutgoing ?? false
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Subviews

private struct DateHeaderView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.4))
                .clipShape(Capsule())
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct MessageBubbleView: View {
    let text: String
    let timeText: String?
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 16))

                if let timeText, !timeText.isEmpty {
                    HStack(spacing: 4) {
                        Spacer()
                        Text(timeText)
                            .font(.caption2)
                            .opacity(0.8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isOutgoing ? Color.blue : Color.gray.opacity(0.35))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(
                maxWidth: UIScreen.main.bounds.width * 0.7,
                alignment: isOutgoing ? .trailing : .leading
            )
            .shadow(radius: 1, x: 0, y: 1)

            if !isOutgoing { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 2)
    }
}
