//
//  RecordingIdEntrySheet.swift
//  URAP Polar H10 V1
//
//  Sheet for entering or generating a 20-character recording ID
//

import SwiftUI

private let recordingIdAllowedCharacters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

private func generateRandomRecordingId() -> String {
    let length = 20
    var result = ""
    result.reserveCapacity(length)
    for _ in 0..<length {
        if let char = recordingIdAllowedCharacters.randomElement() {
            result.append(char)
        }
    }
    return result
}

private func validateRecordingId(_ id: String) -> String? {
    guard id.count == 20 else {
        return "Recording ID must be exactly 20 characters."
    }
    let invalidCharacters = id.filter { !recordingIdAllowedCharacters.contains($0) }
    if !invalidCharacters.isEmpty {
        return "Recording ID can only contain A–Z, a–z, 0–9, '-' and '_'."
    }
    return nil
}

struct RecordingIdEntrySheet: View {
    @Binding var recordingId: String
    @Binding var errorMessage: String?

    let onCancel: () -> Void
    let onStart: (String) -> Void

    @FocusState private var textFieldFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Recording ID"),
                    footer: footerText
                ) {
                    TextField("20-character ID", text: $recordingId)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($textFieldFocused)
                        .onChange(of: recordingId) { _, newValue in
                            if newValue.count > 20 {
                                recordingId = String(newValue.prefix(20))
                            }
                            errorMessage = nil
                        }

                    HStack {
                        Spacer()
                        Button {
                            recordingId = generateRandomRecordingId()
                            errorMessage = nil
                        } label: {
                            Label("Generate", systemImage: "dice")
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Recording ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let validationError = validateRecordingId(recordingId)
                        if let validationError {
                            errorMessage = validationError
                        } else {
                            onStart(recordingId)
                        }
                    }
                    .disabled(recordingId.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    textFieldFocused = true
                }
            }
        }
    }

    private var footerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Use a stable 20-character ID to reference this recording from Python.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

