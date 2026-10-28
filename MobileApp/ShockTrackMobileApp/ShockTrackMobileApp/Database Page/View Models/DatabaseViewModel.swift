//
//  DatabaseViewModel.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-10-28.
//

import Foundation
internal import Combine


@MainActor
final class DatabaseViewModel: ObservableObject {
    @Published var recordings: [RecordingDetails] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = DatabaseService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recordings = try await service.fetchRecordings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
