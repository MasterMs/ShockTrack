//
//  CommunityPostsViewModel.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-09-30.
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
final class CommunityPostsViewModel {
    private let service = CommunityPostService()
    var posts: [CommunityPost] = []
    var errorMessage: String?
    private var listener: ListenerRegistration?

    func start() {
        stop()
        listener = service.listenAllPosts { [weak self] result in
            switch result {
            case .success(let posts):
                self?.posts = posts
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        if let l = listener {
            l.remove()
        }
        listener = nil
    }
}

