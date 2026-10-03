//
//  CommentsViewModel.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-10-01.
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
final class CommentsViewModel {
    var comments: [Comment] = []
    private var listener: ListenerRegistration?

    func start(for post: CommunityPost) {
        listener = CommunityPostService().listenToComments(for: post) { [weak self] in
            self?.comments = $0
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}
