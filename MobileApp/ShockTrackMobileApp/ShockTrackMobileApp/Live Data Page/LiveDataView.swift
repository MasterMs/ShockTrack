//
//  LiveDataView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI
import CoreLocation
import MapKit
import FirebaseDatabaseInternal
internal import FirebaseAuth

struct LiveDataView: View {
    @State private var inputedMake: String = "Mazda"
    @State private var inputedModel: String = "RX7 FC"
    @State private var inputedYear: String = "1991"
    let vehicles = ["RX7 FC", "240SX", "350z"]
    @State private var showRecording = false
    
    // For viewing live recording
    @State private var monitor = LiveRecordingMonitor()
    @State private var showViewer = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Live Data")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // View live recording
                    if let title = monitor.activeTitle {
                        Button { showViewer = true } label: {
                            HStack {
                                Circle().fill(.red).frame(width: 10, height: 10)
                                VStack(alignment: .leading) {
                                    Text("Live now").font(.headline)
                                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Watch").bold()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Start New Recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Location Info
                    LocationCard()
                    
                    // Vehicle Selection
                    VehicleInputCard(make: $inputedMake, model: $inputedModel, year: $inputedYear)
                    
                    Button("Start Recording") {
                        showRecording = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    //.disabled(!vehicleIsValid)
                }
            }
            .fullScreenCover(isPresented: $showViewer) { LiveViewerView() }
        }
        .padding(.horizontal)
        .onAppear {
            UITabBar.appearance().isHidden = false
            monitor.start()
        }
        .onDisappear {
            UITabBar.appearance().isHidden = true
            monitor.stop()
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(vehicleMake: inputedMake, vehicleModel: inputedModel, vehicleYear: inputedYear)
        }
    }
    
    private var vehicleIsValid: Bool {
        guard let y = Int(inputedYear.trimmingCharacters(in: .whitespaces)) else { return false }
        return !inputedMake.trimmingCharacters(in: .whitespaces).isEmpty
            && !inputedModel.trimmingCharacters(in: .whitespaces).isEmpty
            && (1900...2100).contains(y)
    }
}


struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .padding(10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}


// MARK: Cards

struct VehicleInputCard: View {
    @Binding var make: String
    @Binding var model: String
    @Binding var year: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vehicle Info")
                .font(.headline)

            VStack(spacing: 12) {
                CustomTextField(title: "Make", text: $make)
                CustomTextField(title: "Model", text: $model)
                CustomTextField(title: "Year", text: $year, keyboard: .numberPad)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

struct CarFormView: View {
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""

    var body: some View {
        Form {
            Section(header: Text("Car Details")) {
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                TextField("Year", text: $year)
                    .keyboardType(.numberPad)
            }

            Section {
                Button("Save") {
                    // Handle save logic here
                    print("Make: \(make), Model: \(model), Year: \(year)")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Enter Car Info")
    }
}

@Observable
final class LiveRecordingMonitor {
    // Non-nil when ANOTHER device on this account is recording live
    private(set) var activeTitle: String?

    @ObservationIgnored private var ref: DatabaseReference?
    @ObservationIgnored private var handle: DatabaseHandle?

    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference(withPath: "live/\(uid)/status")
        self.ref = ref
        handle = ref.observe(.value) { [weak self] snap in
            guard let d = snap.value as? [String: Any], d["active"] as? Bool == true else {
                self?.activeTitle = nil
                return
            }
            // Don't offer to watch a recording that this same phone is making
            let thisDevice = UIDevice.current.identifierForVendor?.uuidString
            self?.activeTitle = (d["device"] as? String) == thisDevice
                ? nil
                : (d["title"] as? String ?? "Live recording")
        }
    }

    func stop() {
        if let ref, let handle { ref.removeObserver(withHandle: handle) }
        ref = nil
        handle = nil
    }
}

struct ResumeRecordingCard: View {
    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("Graph")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(width: 300)
                    .clipped()
                    .cornerRadius(12)

                Text("RX7, Oct 2nd")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding([.leading, .bottom], 8)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, 16)
        }
        .cornerRadius(12)
    }
}

struct LocationCard: View {
    @State private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Current Location")
                .font(.headline)

            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls { MapUserLocationButton() }
            .frame(width: 300, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            switch locationManager.authorization {
            case .denied, .restricted:
                Text("Location access is off")
                    .font(.subheadline)
                Text("Enable it in Settings to see where you are.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            default:
                Text(locationManager.placeName ?? "Locating…")
                    .font(.subheadline)
                Text(locationManager.locality ?? " ")
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .task { locationManager.start() }
        .onDisappear { locationManager.stop() }
    }
}

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    var placeName: String?
    var locality: String?
    var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocoded: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = latest
        reverseGeocodeIfNeeded(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    private func reverseGeocodeIfNeeded(_ loc: CLLocation) {
        // Geocoding is rate-limited, so only re-lookup after moving ~200 m
        if let last = lastGeocoded, loc.distance(from: last) < 200 { return }
        lastGeocoded = loc
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let p = placemarks?.first else { return }
            self?.placeName = p.name ?? p.thoroughfare
            let city = p.locality ?? ""
            let region = p.administrativeArea ?? ""
            self?.locality = [city, region].filter { !$0.isEmpty }.joined(separator: ", ")
        }
    }
}

struct VehicleSelectionRow: View {
    let vehicle: String
    @Binding var selectedVehicle: String

    var body: some View {
        VStack {
            Text(vehicle)
                .font(.body)
            
        }
        .padding(.horizontal)
        .onTapGesture {
            selectedVehicle = vehicle
        }
    }
}


#Preview {
    LiveDataView()
}

