//
//  ShareSheet.swift
//  URAP Polar H10 V1
//
//  Presents the system share sheet (Mail, AirDrop, etc.) with a file URL.
//  Uses a custom item provider so the zip is copied to a stable location when
//  the activity (e.g. Mail) requests it, ensuring the attachment is sent properly.
//

import SwiftUI
import UIKit

// MARK: - Zip Item Provider

/// Provides the zip file when the share activity (e.g. Mail) requests it, by copying
/// from the source URL to Caches so the file remains readable when the app is backgrounded.
final class ZipActivityItemProvider: UIActivityItemProvider {
    private let sourceURL: URL
    private let suggestedFilename: String
    private var cacheURL: URL?

    init(sourceURL: URL, suggestedFilename: String? = nil) {
        self.sourceURL = sourceURL
        self.suggestedFilename = suggestedFilename ?? sourceURL.lastPathComponent
        super.init(placeholderItem: sourceURL)
    }

    override var item: Any {
        // Copy to Caches so Mail (or other apps) can read the file when they need it.
        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return sourceURL
        }
        let shareDir = cachesDir.appendingPathComponent("Share", isDirectory: true)
        try? fileManager.createDirectory(at: shareDir, withIntermediateDirectories: true)
        let destURL = shareDir.appendingPathComponent(suggestedFilename)
        try? fileManager.removeItem(at: destURL)
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            cacheURL = destURL
            return destURL
        } catch {
            return sourceURL
        }
    }

    /// Call from completion handler to remove the cache copy after the share is done.
    func cleanupCacheFile() {
        guard let url = cacheURL else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 120) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Share Sheet View

/// Presents UIActivityViewController with the given file URL so the user can share via Mail, AirDrop, etc.
struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL
    var suggestedFilename: String?
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let filename = suggestedFilename ?? url.lastPathComponent
        let provider = ZipActivityItemProvider(sourceURL: url, suggestedFilename: filename)
        let vc = UIActivityViewController(
            activityItems: [provider],
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, _, _, _ in
            provider.cleanupCacheFile()
            onDismiss?()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
