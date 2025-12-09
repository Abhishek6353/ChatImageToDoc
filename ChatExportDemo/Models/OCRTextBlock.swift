//
//  OCRTextBlock.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import Foundation
import CoreGraphics

struct OCRTextBlock: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect   // normalized [0,1] coords from Vision
    let pageIndex: Int        // which screenshot index
}
