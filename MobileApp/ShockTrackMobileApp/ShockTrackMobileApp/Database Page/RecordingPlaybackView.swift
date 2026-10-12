import SwiftUI
import CoreLocation
import MapKit
internal import Combine

final class GPSTelemetryMirror {
    static let shared = GPSTelemetryMirror()
    var latestLocation: CLLocation?
}

struct RecordingPlaybackView: View {
    @State private var telemetry = GPSTelemetry()
    @State private var isPlaying: Bool = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            Group {
                if isLandscape {
                    PlaybackLandscapeLayout(kph: telemetry.kph, direction: telemetry.direction, isPlaying: $isPlaying)
                        .toolbar(.hidden, for: .tabBar)
                } else {
                    PlaybackPortraitLayout(kph: telemetry.kph, direction: telemetry.direction, isPlaying: $isPlaying, cameraPosition: $cameraPosition)
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
                    if let loc = telemetryLastLocation() {
                        cameraPosition = .region(MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
                    }
                } else {
                    telemetry.stop()
                }
            }
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                // If playing, try to center map based on telemetry's latest heading/speed using CoreLocation services
                if isPlaying, let mgr = GPSTelemetryMirror.shared.latestLocation {
                    cameraPosition = .region(MKCoordinateRegion(center: mgr.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
                }
            }
            .onDisappear { telemetry.stop() }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

private func telemetryLastLocation() -> CLLocation? {
    // Access via NotificationCenter or a shared reference would be ideal; for now, we can downcast from the preview or pass through RecordingPlaybackView.
    return nil
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
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        VStack(spacing: 20) {
            // Top: Speed + Compass side-by-side + Map
            HStack(spacing: 30) {
                SpeedDisplay(kph: kph)
                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.3))
                CompassDisplay(direction: direction)
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .frame(width: 140, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal)

            // Bottom: Graph fills remaining space
            GraphView(isPlaying: isPlaying)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .padding()
    }
}
