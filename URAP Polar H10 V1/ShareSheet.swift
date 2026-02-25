//
//  ShareSheet.swift
//  URAP Polar H10 V1
//
//  Presents the system share sheet (Mail, AirDrop, etc.) with a file URL.
//

import SwiftUI
import UIKit

/// Presents UIActivityViewController with the given file URL so the user can share via Mail, AirDrop, etc.
struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
