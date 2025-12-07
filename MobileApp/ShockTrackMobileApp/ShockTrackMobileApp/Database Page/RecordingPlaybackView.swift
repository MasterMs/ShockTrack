import SwiftUI

struct RecordingPlaybackView: View {
    @State private var isPlaying: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Recording Playback")
                .font(.title)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)

            // Graph placeholder (reuse the same asset for now)
            Image("Graph")
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .accessibilityLabel("Playback graph")
                .padding(.horizontal)

            Spacer()

            // Start/Stop playback button
            Button(action: { isPlaying.toggle() }) {
                Text(isPlaying ? "Stop Playback" : "Start Playback")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPlaying ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationView {
        RecordingPlaybackView()
    }
}
