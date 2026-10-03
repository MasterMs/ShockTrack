//
//  CommunityPost.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-09-30.
//

import Foundation
import FirebaseFirestore

struct CommunityPost: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var car: String
    var content: String
    var imageName: String?
    var assetImageName: String?
    var ownerUid: String
    var ownerName: String?
    var createdAt: Date
    var updatedAt: Date
    
    var views: Int?
    var viewedBy: [String]?
    var viewCount: Int { viewedBy?.count ?? 0 }
    func isViewed(by userID: String) -> Bool { viewedBy?.contains(userID) ?? false }
    
    var comments: Int?
    var commentedBy: [String]?
    var commentCount: Int { commentedBy?.count ?? 0 }
    func hasCommented(by userID: String) -> Bool { commentedBy?.contains(userID) ?? false}
    
    var likes: Int?
    var likedBy: [String]?
    var likeCount: Int { likedBy?.count ?? 0 }
    func isLiked(by userID: String) -> Bool { likedBy?.contains(userID) ?? false }
}

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var authorUid: String
    var authorName: String?
    @ServerTimestamp var createdAt: Date?
}
