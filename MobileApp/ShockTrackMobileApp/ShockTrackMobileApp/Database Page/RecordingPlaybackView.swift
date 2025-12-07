import SwiftUI

struct RecordingPlaybackView: View {
    @State private var telemetry = DummyTelemetryModel()
    @State private var isPlaying: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            Group {
                if isLandscape {
                    PlaybackLandscapeLayout(kph: telemetry.kph, direction: telemetry.direction, isPlaying: $isPlaying)
                        .toolbar(.hidden, for: .tabBar)
                } else {
                    PlaybackPortraitLayout(kph: telemetry.kph, direction: telemetry.direction, isPlaying: $isPlaying)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                // Start in paused state; user controls playback
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    telemetry.start()
                } else {
                    telemetry.stop()
                }
            }
            .onDisappear { telemetry.stop() }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

#Preview {
    RecordingPlaybackView()
}

// MARK: - Landscape
private struct PlaybackLandscapeLayout: View {
    let kph: Int
    let direction: String
    @Binding var isPlaying: Bool

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                // Left: Graph (reuse GraphView)
                GraphView(isPlaying: isPlaying)
                    .frame(width: UIScreen.main.bounds.width * 0.6)

                // Right: Speed + Compass
                VStack(spacing: 30) {
                    SpeedDisplay(kph: kph)
                    CompassDisplay(direction: direction)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()

            Button(action: { isPlaying.toggle() }) {
                Label(isPlaying ? "Pause Playback" : "Play Playback", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPlaying ? Color.orange : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Portrait
private struct PlaybackPortraitLayout: View {
    let kph: Int
    let direction: String
    @Binding var isPlaying: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Top: Speed + Compass side-by-side
            HStack(spacing: 30) {
                SpeedDisplay(kph: kph)
                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.3))
                CompassDisplay(direction: direction)
            }
            .padding(.horizontal)

            // Bottom: Graph fills remaining space
            GraphView(isPlaying: isPlaying)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: { isPlaying.toggle() }) {
                Label(isPlaying ? "Pause Recording" : "Play Recording", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPlaying ? Color.orange : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

