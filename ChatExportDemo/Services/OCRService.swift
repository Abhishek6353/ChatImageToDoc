//
//  OCRService.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import Foundation
import UIKit
import Vision

final class OCRService {
    func recognizeText(
        in images: [UIImage],
        completion: @escaping ([OCRTextBlock]) -> Void
    ) {
        var allBlocks: [OCRTextBlock] = []

        let group = DispatchGroup()

        for (index, image) in images.enumerated() {
            guard let cgImage = image.cgImage else { continue }
            group.enter()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                guard error == nil else { return }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks: [OCRTextBlock] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return OCRTextBlock(
                        text: candidate.string,
                        boundingBox: obs.boundingBox,
                        pageIndex: index
                    )
                }
                allBlocks.append(contentsOf: blocks)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try handler.perform([request])
            } catch {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(allBlocks)
        }
    }
}
