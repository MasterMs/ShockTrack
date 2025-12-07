import SwiftUI

struct CreatePostView: View {
    @State private var title: String = ""
    @State private var description: String = ""

    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Enter a title", text: $title)
            }
            Section(header: Text("Description")) {
                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }
            Section {
                Button("Submit") { }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Create Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        CreatePostView()
    }
}
