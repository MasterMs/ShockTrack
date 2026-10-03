import SwiftUI
import FirebaseAuthSwiftUI
internal import FirebaseAuth
import PhotosUI

struct CreatePostView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var car: String = ""
    @State private var content: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var assetImageName: String? = nil

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $title)
                TextField("Car", text: $car)
                TextField("Content", text: $content, axis: .vertical)
                    .lineLimit(5...10)

                PhotosPicker("Select Image", selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }

                Picker("Image Details", selection: Binding(
                    get: { assetImageName ?? "" },
                    set: { assetImageName = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    Text("RX7").tag("RX7")
                    Text("GT86").tag("GT86")
                    Text("S13").tag("S13")
                }
            }
            Section {
                Button("Post") { Task { await create() } }
                    .disabled(!canPost)
            }
        }
        .navigationTitle("New Post")
    }

    private var canPost: Bool { !(title.isEmpty || car.isEmpty || content.isEmpty || authService.currentUser == nil) }

    private func create() async {
        guard let uid = authService.currentUser?.uid else { return }
        let name = authService.currentUser?.displayName
        do {
            try await CommunityPostService().createPost(title: title, car: car, content: content, imageData: nil, assetImageName: assetImageName, ownerUid: uid, ownerName: name)
            await MainActor.run { dismiss() }
        } catch {
            print("Failed to create post: \(error)")
        }
    }
}

/*
 #Preview {
    NavigationView {
        CreatePostView()
    }
 }
 */
