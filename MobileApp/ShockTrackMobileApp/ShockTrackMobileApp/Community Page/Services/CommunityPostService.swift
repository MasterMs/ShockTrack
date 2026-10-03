//
//  CommunityPostService.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-09-30.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

final class CommunityPostService {
    private let db = Firestore.firestore()
    private var collection: CollectionReference { db.collection("community_posts") }
    private var storage: Storage { Storage.storage() }
    private var imagesRoot: StorageReference { storage.reference().child("community_posts") }

    func listenAllPosts(completion: @escaping (Result<[CommunityPost], Error>) -> Void) -> ListenerRegistration {
        return collection
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, error in
                if let error = error { completion(.failure(error)); return }
                let posts = snap?.documents.compactMap { try? $0.data(as: CommunityPost.self) } ?? []
                completion(.success(posts))
            }
    }
    
    func listenToComments(for post: CommunityPost, onChange: @escaping ([Comment]) -> Void) -> ListenerRegistration? {
        guard let postID = post.id else { return nil }
        return collection.document(postID).collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                let comments = snapshot?.documents.compactMap { try? $0.data(as: Comment.self) } ?? []
                onChange(comments)
            }
    }
    
    func createPost(title: String, car: String, content: String, imageData: Data?, assetImageName: String?, ownerUid: String, ownerName: String?) async throws {
        let now = Date()
        let ref = collection.document()
        var post = CommunityPost(
            id: ref.documentID,
            title: title,
            car: car,
            content: content,
            imageName: nil,
            assetImageName: assetImageName,
            ownerUid: ownerUid,
            ownerName: ownerName,
            createdAt: now,
            updatedAt: now,
            views: 0,
            viewedBy: [],
            comments: 0,
            commentedBy: [],
            likedBy: []
            
        )

        if let data = imageData {
            let storagePath = try await uploadImage(forPostId: ref.documentID, data: data)
            post.imageName = storagePath
        }

        try await ref.setData(from: post)
    }
    
    func uploadImage(forPostId postId: String, data: Data, contentType: String = "image/jpeg") async throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        let ref = imagesRoot.child(postId).child("images").child(fileName)
        let _ = try await ref.putDataAsync(data, metadata: {
            let m = StorageMetadata()
            m.contentType = contentType
            return m
        }())
        return ref.fullPath
    }

    func recordView(on post: CommunityPost, userID: String) async throws {
        guard let id = post.id else { return }
        try await collection.document(id).updateData([
            "viewedBy": FieldValue.arrayUnion([userID])
        ])
    }
    
    func setLike(_ liked: Bool, on post: CommunityPost, userID: String) async throws {
        guard let id = post.id else { return }
        try await collection.document(id).updateData([
            "likedBy": liked
                ? FieldValue.arrayUnion([userID])
                : FieldValue.arrayRemove([userID])
        ])
    }
    
    func addComment(to post: CommunityPost, text: String, userID: String, userName: String?) async throws {
        guard let postID = post.id else { return }
        let postRef = collection.document(postID)
        let commentRef = postRef.collection("comments").document()

        let comment = Comment(text: text, authorUid: userID, authorName: userName, createdAt: nil)

        let batch = Firestore.firestore().batch()
        try batch.setData(from: comment, forDocument: commentRef)
        batch.updateData([
            "comments": FieldValue.increment(Int64(1)),
            "commentedBy": FieldValue.arrayUnion([userID])
        ], forDocument: postRef)
        try await batch.commit()
    }

    func deleteComment(_ comment: Comment, from post: CommunityPost) async throws {
        guard let postID = post.id, let commentID = comment.id else { return }
        let postRef = collection.document(postID)
        let commentsRef = postRef.collection("comments")

        // Check for is user has other comments on the post
        let mine = try await commentsRef
            .whereField("authorUid", isEqualTo: comment.authorUid)
            .limit(to: 2)
            .getDocuments()
        let isLastOne = mine.documents.count <= 1

        var postUpdate: [String: Any] = ["comments": FieldValue.increment(Int64(-1))]
        if isLastOne {
            postUpdate["commentedBy"] = FieldValue.arrayRemove([comment.authorUid])
        }

        let batch = Firestore.firestore().batch()
        batch.deleteDocument(commentsRef.document(commentID))
        batch.updateData(postUpdate, forDocument: postRef)
        try await batch.commit()
    }
    
    func updatePost(_ post: CommunityPost, asUser uid: String) async throws {
        guard let id = post.id else {
            throw NSError(domain: "Community", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing post id"])
        }
        guard post.ownerUid == uid else {
            throw NSError(domain: "Community", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not owner"])
        }

        try await collection.document(id).updateData([
            "title": post.title,
            "car": post.car,
            "content": post.content,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deletePost(_ post: CommunityPost, asUser uid: String) async throws {
        guard let id = post.id else { return }
        guard post.ownerUid == uid else { throw NSError(domain: "Community", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not owner"]) }
        try await collection.document(id).delete()
    }
}
