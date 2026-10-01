//
//  CommunityView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI
internal import FirebaseAuth
import FirebaseFirestore
import FirebaseAuthSwiftUI
import FirebaseStorage

struct CommunityView: View {
    @Environment(AuthService.self) private var authService
    @State private var vm = CommunityPostsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Community")
                            .font(.largeTitle)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                        
                        ForEach(vm.posts) { post in
                            CommunityPostCard(post: post)
                        }
                    }
                }
                .padding(.horizontal)
                    
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: CreatePostView()) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
}
    
struct CommunityPostDetail: View {
    let post: CommunityPost
    @Environment(AuthService.self) private var authService
    @State private var isUpdating = false
    
    @State private var commentsVM = CommentsViewModel()
    @State private var draft = ""
    @State private var isSending = false
    
    private var userID: String? { authService.currentUser?.uid }
    private var isViewed: Bool { userID.map { post.isViewed(by: $0) } ?? false }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title).font(.largeTitle).bold()
                if let assetName = post.assetImageName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                }
                Text(post.car).font(.headline)
                Text(post.content).font(.body)
                if authService.currentUser?.uid == post.ownerUid {
                    NavigationLink("Edit Post") { EditPostView(post: post) }
                        .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                Text("Comments").font(.headline)

                if commentsVM.comments.isEmpty {
                    Text("No comments yet").foregroundStyle(.secondary)
                }
                
                ForEach(commentsVM.comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comment.authorName ?? "Anonymous")
                                .font(.subheadline).bold()
                            if let date = comment.createdAt {
                                Text(date, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if comment.authorUid == authService.currentUser?.uid {
                                Button(role: .destructive) {
                                    Task { try? await CommunityPostService().deleteComment(comment, from: post) }
                                } label: { Image(systemName: "trash").font(.caption) }
                            }
                        }
                        Text(comment.text).font(.body)
                    }
                }
            }.padding()
        }
        .safeAreaInset(edge: .bottom) { composer }
        .task {
            commentsVM.start(for: post)
            guard let userID, !isViewed else { return }
            try? await CommunityPostService().recordView(on: post, userID: userID)
        }
        .onDisappear { commentsVM.stop() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var composer: some View {
        HStack {
            TextField("Add a comment", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button("Send") { send() }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding()
        .background(.bar)
    }

    private func send() {
        guard let user = authService.currentUser else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await CommunityPostService().addComment(
                    to: post, text: text, userID: user.uid, userName: user.displayName)
                draft = ""
            } catch {
                print("Comment failed: \(error)")
            }
        }
    }
}


struct EditPostView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @State var post: CommunityPost
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $post.title)
                TextField("Car", text: $post.car)
                TextField("Content", text: $post.content, axis: .vertical)
            }
            Section { Button("Save") { Task { await save() } }.disabled(authService.currentUser?.uid != post.ownerUid) }
        }
        .navigationTitle("Edit Post")
    }
    
    private func save() async {
        guard let uid = authService.currentUser?.uid else { return }
        do { try await CommunityPostService().updatePost(post, asUser: uid); await MainActor.run { dismiss() } } catch { print("Failed to save: \(error)") }
    }
}

struct CommunityPostCard: View {
    let post: CommunityPost
    @Environment(AuthService.self) private var authService
    @State private var isUpdating = false

    private var userID: String? { authService.currentUser?.uid }
    private var isLiked: Bool { userID.map { post.isLiked(by: $0) } ?? false }
    private var isViewed: Bool { userID.map { post.isViewed(by: $0) } ?? false }
    private var hasCommented: Bool { userID.map { post.hasCommented(by: $0) } ?? false }

    var body: some View {
        VStack(alignment: .leading) {
            NavigationLink(destination: CommunityPostDetail(post: post)) {
                ZStack(alignment: .bottomLeading) {
                    Image(post.assetImageName ?? "RX7")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: 370)
                        .clipped()
                        .cornerRadius(8)
                    Text(post.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .padding([.leading, .bottom], 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Label("\(post.viewCount)", systemImage: isViewed ? "eye.fill" : "eye")
                    .font(.caption)
                    .foregroundStyle(isViewed ? .blue : .secondary)

                Button(action: toggleLike) {
                    Label("\(post.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundStyle(isLiked ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(userID == nil || isUpdating)
                .accessibilityLabel(isLiked ? "Unlike, \(post.likeCount) likes" : "Like, \(post.likeCount) likes")
                
                NavigationLink(destination: CommunityPostDetail(post: post)) {
                    Label("\(post.comments ?? 0)", systemImage: hasCommented ? "text.bubble.fill" : "text.bubble")
                        .font(.caption)
                        .foregroundStyle(hasCommented ? .green : .secondary)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasCommented ? "Comments, \(post.comments ?? 0), you commented" : "Comments, \(post.comments ?? 0)")
                
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private func toggleLike() {
        guard let userID, !isUpdating else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false }
            do {
                try await CommunityPostService().setLike(!isLiked, on: post, userID: userID)
            } catch {
                print("Like toggle failed: \(error)")
            }
        }
    }
}
