//
//  RecordingView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-11-17.
//

import SwiftUI
import Foundation
import Charts
import FirebaseDatabase
internal import FirebaseAuth
import CoreLocation
import MapKit

// Variables for suspension data received from websocket
struct LiveSensorData: Codable {
    let accel_x: Double
    let accel_y: Double
    let accel_z: Double
    let gyro_x: Double
    let gyro_y: Double
    let gyro_z: Double
}

struct GraphPoint3: Identifiable {
    let id = UUID()
    let index: Int
    let x: Double
    let y: Double
    let z: Double
}


// Function for uploading suspension data taken in from the websocket and sending it to Firebase.
@Observable
final class LiveUploader: NSObject, URLSessionWebSocketDelegate {
    @ObservationIgnored private var webSocketTask: URLSessionWebSocketTask?
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private let socketURLString: String
    @ObservationIgnored private let basePath: String
    @ObservationIgnored var onConnectionChange: ((Bool) -> Void)?

    private(set) var isConnected: Bool = false

    init(socketURLString: String, basePath: String = "sensors/current") {
        self.socketURLString = socketURLString
        self.basePath = basePath
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[LiveUploader] No authenticated user; aborting start().")
            return
        }
        guard let url = URL(string: socketURLString) else {
            print("[LiveUploader] Invalid WebSocket URL: \(socketURLString)")
            return
        }
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        listen(on: task, uid: uid)
    }

    func stop() {
        let task = webSocketTask
        webSocketTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        setConnected(false)
    }

    private func setConnected(_ value: Bool) {
        guard isConnected != value else { return }
        isConnected = value
        onConnectionChange?(value)
    }

    private func listen(on task: URLSessionWebSocketTask, uid: String) {
        task.receive { [weak self] result in
            // Ignore callbacks from a task that has been replaced or stopped
            guard let self, task === self.webSocketTask else { return }

            switch result {
            case .failure(let error):
                print("[LiveUploader] WebSocket receive error: \(error)")
                self.setConnected(false)
                return                  // do NOT re-arm after a failure
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleText(text, uid: uid)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleText(text, uid: uid)
                    }
                @unknown default:
                    break
                }
            }
            self.listen(on: task, uid: uid)
        }
    }

    private func handleText(_ text: String, uid: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let sensor = try JSONDecoder().decode(LiveSensorData.self, from: data)
            let payload: [String: Any] = [
                "t": ServerValue.timestamp(),
                "accel_x": sensor.accel_x,
                "accel_y": sensor.accel_y,
                "accel_z": sensor.accel_z,
                "gyro_x": sensor.gyro_x,
                "gyro_y": sensor.gyro_y,
                "gyro_z": sensor.gyro_z
            ]
            Database.database().reference(withPath: "\(basePath)/\(uid)")
                .setValue(payload) { error, _ in
                    if let error { print("[LiveUploader] Failed to write live payload: \(error)") }
                }
        } catch {
            print("[LiveUploader] JSON decode error: \(error) for text: \(text)")
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        guard webSocketTask === self.webSocketTask else { return }
        setConnected(true)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask === self.webSocketTask else { return }
        setConnected(false)
    }
}

// Function for sending sensor data recieved from the websocket to Firebase
@Observable
final class FirebaseSensorModel {
    var samples: [GraphPoint3] = []
    private var index: Int = 0
    private let maxCount: Int

    private var ref: DatabaseReference?
    private var handle: DatabaseHandle?
    private let path: String

    init(path: String = "sensors/current", maxCount: Int = 240) {
        self.path = path
        self.maxCount = maxCount
    }

    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[FirebaseSensorModel] No authenticated user; aborting start().")
            return
        }
        let fullPath = path.hasSuffix("/") ? path + uid : path + "/" + uid
        let ref = Database.database().reference(withPath: fullPath)
        self.ref = ref
        // Listen for value changes on the node that contains the six fields
        handle = ref.observe(.value) { [weak self] (snapshot: DataSnapshot) in
            guard let self else { return }
            guard let dict = snapshot.value as? [String: Any] else { return }
            func d(_ key: String) -> Double? {
                if let v = dict[key] as? Double { return v }
                if let s = dict[key] as? String, let v = Double(s) { return v }
                if let n = dict[key] as? NSNumber { return n.doubleValue }
                return nil
            }
            guard let ax = d("accel_x"),
                  let ay = d("accel_y"),
                  let az = d("accel_z"),
                  let gx = d("gyro_x"),
                  let gy = d("gyro_y"),
                  let gz = d("gyro_z") else {
                return
            }
            // Build and append a new sample
            let point = GraphPoint3(index: index, x: ax, y: ay, z: az)
            samples.append(point)
            index += 1
            if samples.count > maxCount {
                samples.removeFirst(samples.count - maxCount)
            }
        }
    }

    func stop() {
        if let ref, let handle {
            ref.removeObserver(withHandle: handle)
        }
        handle = nil
        ref = nil
    }
}

// Function for GPS handling for displaying postion on Map in real time
@Observable
final class GPSTelemetry: NSObject, CLLocationManagerDelegate {
    // GPS variables
    private let manager = CLLocationManager()
    private(set) var kph: Int = 0
    private(set) var direction: String = "N"
    private(set) var latestLocation: CLLocation?

    private var lastDirectionDegrees: CLLocationDirection = 0
    private var hasDirection: Bool = false

    // Set map variables on intialization
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    // Functon to start displaying postion on map
    func start() {
        // Request GPS authorization if needed
        if CLLocationManager.authorizationStatus() == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Start updating the GPS location
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 1 // degrees
            manager.startUpdatingHeading()
        }
    }

    // Stop updating location on Recording View close
    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // CLLocationManagerDelegate for handling the location tracking and gathering speed with smoothing
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let speedMS = max(0, last.speed)
        let rawKPH = speedMS * 3.6
        // Low-pass filter speed (alpha 0.2)
        let smoothed = 0.8 * Double(kph) + 0.2 * rawKPH
        kph = Int(max(0, smoothed).rounded())

        // Smooth direction using course if valid
        if last.course >= 0 {
            let alpha = 0.2
            if !hasDirection { lastDirectionDegrees = last.course; hasDirection = true }
            let delta = angleDeltaDegrees(from: lastDirectionDegrees, to: last.course)
            lastDirectionDegrees = normalizeDegrees(lastDirectionDegrees + alpha * delta)
            direction = GPSTelemetry.directionString(from: lastDirectionDegrees)
        }
        latestLocation = last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Fallback to heading if course wasn't available
        let trueHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        direction = GPSTelemetry.directionString(from: trueHeading)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }

    // Function for getting compass direction for an 8 point compass
    private static func directionString(from degrees: CLLocationDirection) -> String {
        // 8-point compass
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let index = Int((degrees + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return dirs[max(0, min(dirs.count - 1, index))]
    }

    // Functions for getting degrees required for determining compass position
    private func normalizeDegrees(_ deg: CLLocationDirection) -> CLLocationDirection {
        var d = deg.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }

    private func angleDeltaDegrees(from: CLLocationDirection, to: CLLocationDirection) -> CLLocationDirection {
        var diff = (to - from).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }
}

// Dummy Fake Sensor Data for Testing sending and reciving data from Firebase
@Observable
final class FakeSensorWriter {
    private var task: Task<Void, Never>?

    func start(path: String = "sensors/current", hz: Double = 10) {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference(withPath: "\(path)/\(uid)")

        task = Task {
            var phase = 0.0
            while !Task.isCancelled {
                phase += 0.2
                let values: [String: Any] = [
                    "t": ServerValue.timestamp(),
                    "accel_x": sin(phase),
                    "accel_y": cos(phase) - 1,
                    "accel_z": 0.1 * sin(phase * 3),
                    "gyro_x": 20 * sin(phase),
                    "gyro_y": 20 * cos(phase),
                    "gyro_z": 0
                ]
                do { try await ref.setValue(values) }
                catch { print("Fake write failed: \(error)"); break }
                try? await Task.sleep(for: .seconds(1 / hz))
            }
        }
    }

    func stop() { task?.cancel(); task = nil }
}

// Overarching Recording View
struct RecordingView: View {
    
    // Variable for GPS telemetry
    @State private var telemetry = GPSTelemetry()
    // Variable for websocket data uploaded
    @State private var uploader = LiveUploader(socketURLString: "ws://192.168.2.12:8000/ws")
    // Variable for Testing Sensor Data
    @State private var fakeSensorData = FakeSensorWriter()
    // States of uploading, fake sensor data and websocket connection.
    @State private var isUploading: Bool = false
    @State private var isFakeSensorData: Bool = false
    @State private var isConnected: Bool = false
    // Settings for Map view
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var trail: [CLLocationCoordinate2D] = []
    @State private var showingSettings: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                layout(for: proxy.size)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .toolbar(.hidden, for: .tabBar)
            .navigationTitle("Recording")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { recordingToolbar }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(
                    isConnected: isConnected,
                    isUploading: $isUploading,
                    isFakeSensorData: $isFakeSensorData,
                    onClose: { showingSettings = false }
                )
            }
            .onAppear { handleAppear() }
            .onDisappear { handleDisappear() }
            .onChange(of: isUploading) { _, on in setUploading(on) }
            .onChange(of: isFakeSensorData) { _, on in setFakeSensor(on) }
            .onChange(of: telemetry.latestLocation) { _, newLoc in
                if let loc = newLoc { handleLocation(loc) }
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func layout(for size: CGSize) -> some View {
        if size.width > size.height {
            LandscapeLayout(kph: telemetry.kph, direction: telemetry.direction,
                            isUploading: $isUploading, isFakeSensorData: $isFakeSensorData,
                            cameraPosition: $cameraPosition, trail: $trail)
        } else {
            PortraitLayout(kph: telemetry.kph, direction: telemetry.direction,
                           isConnected: $isConnected, isUploading: $isUploading,
                           isFakeSensorData: $isFakeSensorData,
                           cameraPosition: $cameraPosition, trail: $trail)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var recordingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            BreathingDot()
                .padding(.trailing, 4)
                .accessibilityLabel("Recording")
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
        }
    }

    // MARK: - Lifecycle and toggles

    private func handleAppear() {
        OrientationManager.set(.allButUpsideDown)
        telemetry.start()
        uploader.onConnectionChange = { connected in isConnected = connected }
        if isUploading { uploader.start() }
        if isFakeSensorData { fakeSensorData.start() }
    }

    private func handleDisappear() {
        OrientationManager.set(.portrait)
        telemetry.stop()
        uploader.stop()
        fakeSensorData.stop()
    }

    private func setUploading(_ on: Bool) {
        if on { uploader.start() } else { uploader.stop() }
    }

    private func setFakeSensor(_ on: Bool) {
        if on { fakeSensorData.start() } else { fakeSensorData.stop() }
    }

    // MARK: - GPS

    private func handleLocation(_ loc: CLLocation) {
        trail.append(loc.coordinate)
        if trail.count > 200 { trail.removeFirst(trail.count - 200) }

        let spanVal = zoomSpan(forKPH: Double(telemetry.kph))
        let span = MKCoordinateSpan(latitudeDelta: spanVal, longitudeDelta: spanVal)
        cameraPosition = .region(MKCoordinateRegion(center: loc.coordinate, span: span))
    }

    /// Maps 0...120 km/h to a 0.003...0.02 degree span.
    private func zoomSpan(forKPH kph: Double) -> Double {
        let minSpan: Double = 0.003
        let maxSpan: Double = 0.02
        let t: Double = min(max(kph / 120.0, 0.0), 1.0)
        return minSpan + (maxSpan - minSpan) * t
    }
}
 
// MARK: - Landscape
struct LandscapeLayout: View {
    
    // Variables for speed and direction
    let kph: Int
    let direction: String
    
    // Variables for uploading and Fake sensor data
    @Binding var isUploading: Bool
    @Binding var isFakeSensorData: Bool
    
    // Additional variables for Mapping with camera positon and the drawn trail.
    @Binding var cameraPosition: MapCameraPosition
    @Binding var trail: [CLLocationCoordinate2D]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                // Left: Suspension Graph
                GraphView()
                    .frame(width: 350)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical)
                
                // Right: Map with overlays
                ZStack(alignment: .bottom) {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        // Trail polyline
                        MapPolyline(coordinates: trail)
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
                    // Speed and compass display on top of the Map
                    HStack {
                        SpeedDisplay(kph: kph)
                            .padding()
                        Spacer()
                        CompassDisplay(direction: direction)
                            .padding()
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
            }
            .padding()

            // Dismisses Recording View screen on press of "Stop Recording" button.
            Button("Stop Recording") {
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}


// MARK: - Portrait
struct PortraitLayout: View {
    // Variables for speed and direction
    let kph: Int
    let direction: String
    // Variables for uploading and Fake sensor data
    @Binding var isConnected: Bool
    @Binding var isUploading: Bool
    @Binding var isFakeSensorData: Bool
    // Additional variables for Mapping with camera positon and the drawn trail.
    @Binding var cameraPosition: MapCameraPosition
    @Binding var trail: [CLLocationCoordinate2D]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // Top: Graph
            GraphView()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .padding(.horizontal)

            // Bottom: Map with overlays
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    // Trail polyline
                    MapPolyline(coordinates: trail)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                // Speed and compass display on top of the Map
                HStack {
                    SpeedDisplay(kph: kph)
                        .padding()
                    Spacer()
                    CompassDisplay(direction: direction)
                        .padding()
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal)

            Button("Stop Recording") { dismiss() }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.vertical)
    }
}

// View for settings screen in Recording View
private struct SettingsSheet: View {
    let isConnected: Bool
    @Binding var isUploading: Bool
    @Binding var isFakeSensorData: Bool
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            // Status of connection to Websocket
            Form {
                Section(header: Text("Status")) {
                    HStack {
                        Text("Websocket")
                        Spacer()
                        Text(isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(isConnected ? .green : .red)
                    }
                }
                // Controls for toggling upload from phone and the testing data.
                Section(header: Text("Controls")) {
                    Toggle("Uploading Live", isOn: $isUploading)
                    Toggle("Debug Mode", isOn: $isFakeSensorData)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                }
            }
        }
    }
}

// MARK: - Components
// View for graphing suspenion data
struct GraphView: View {
    var isPlaying: Bool = true
    @State private var model = FirebaseSensorModel(path: "sensors/current")

    var body: some View {
        let xMax = (model.samples.last?.index ?? 0)
        let window = max(60, min(240, model.samples.count))
        let xMin = max(0, xMax - window)

        return Chart {
            ForEach(model.samples) { point in
                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Acceleration", point.x)
                )
                .foregroundStyle(by: .value("Axis", "X"))

                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Acceleration", point.y)
                )
                .foregroundStyle(by: .value("Axis", "Y"))

                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Acceleration", point.z)
                )
                .foregroundStyle(by: .value("Axis", "Z"))
            }
        }
        .chartXScale(domain: xMin...xMax)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartYAxisLabel("Acceleration")
        .chartXAxisLabel("Sample")
        .onAppear {
            model.start()
        }
        .onDisappear { model.stop() }
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// View for speed display on top of map
struct SpeedDisplay: View {
    let kph: Int

    var body: some View {
        VStack {
            Text("\(kph)")
                .font(.system(size: 48, weight: .bold))
            Text("KPH")
                .font(.subheadline)
                .opacity(0.9)
        }
        .padding(16)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// View for compass display on top of map
struct CompassDisplay: View {
    let direction: String

    var body: some View {
        VStack {
            //Image(systemName: "location.north.line.fill")
            //    .font(.system(size: 40))
            Text(direction)
                .font(.title2)
                .opacity(0.9)
        }
        .padding(16)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct BreathingDot: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 2 * .pi / 3.0) + 1) / 2   // 0...1, 1.6 s per breath

            Circle()
                .fill(.red)
                .frame(width: 24, height: 24)
                .scaleEffect(0.7 + 0.3 * phase)
                .opacity(0.5 + 0.5 * phase)
        }
        .frame(width: 32, height: 32)   // fixed size so the toolbar lays it out correctly
    }
}

#Preview {
    RecordingView()
}
