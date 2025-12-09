//
//  ScreenshotPickerView.swift
//  ChatExportDemo
//
//  Created by Apple on 09/12/25.
//

import SwiftUI

import SwiftUI
import PhotosUI

struct ScreenshotPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var images: [UIImage]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0              // 0 = no limit (multi-select)
        configuration.filter = .images                // we only want images (screenshots are images)

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: ScreenshotPickerView

        init(parent: ScreenshotPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                parent.dismiss()
                return
            }

            parent.images.removeAll()

            let group = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.images.append(image)
                            }
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.dismiss()
            }
        }
    }
}

//
//#Preview {
//    ScreenshotPickerView()
//}
