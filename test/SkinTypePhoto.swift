//
//  SkinTypePhoto.swift
//  test
//
//  Created by Aileen Kim on 7/20/26.
//

import PhotosUI
import SwiftUI

struct SkinTypePhotoPicker: View {
    @Binding var skinType: FitzpatrickType
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var aiReason: String = ""
    @State private var showConfirmation = false
    @State private var suggestedType: FitzpatrickType?

    var body: some View {
        VStack(spacing: 8) {
            PhotosPicker("Estimate skin type from photo", selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { newItem in
                    Task { await handleSelection(newItem) }
                }

            if isLoading {
                ProgressView("Analyzing...")
            }
        }
        .alert("Suggested skin type", isPresented: $showConfirmation) {
            Button("Use this") {
                if let suggestedType { skinType = suggestedType }
            }
            Button("Keep my selection", role: .cancel) {}
        } message: {
            Text(aiReason)
        }
    }

    func handleSelection(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }

        isLoading = true
        defer { isLoading = false }

        let base64 = data.base64EncodedString()
        guard let url = URL(string: "https://uvbuddy-worker.uvbuddy.workers.dev/skin-type") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "imageBase64": base64,
            "mediaType": "image/jpeg"
        ])

        guard let (responseData, _) = try? await URLSession.shared.data(for: request),
              let result = try? JSONDecoder().decode(SkinTypeAIResponse.self, from: responseData) else { return }

        if let type = FitzpatrickType(rawValue: result.type) {
            suggestedType = type
            aiReason = result.reason
            showConfirmation = true
        }
    }
}

struct SkinTypeAIResponse: Decodable {
    let type: Int
    let reason: String
}
