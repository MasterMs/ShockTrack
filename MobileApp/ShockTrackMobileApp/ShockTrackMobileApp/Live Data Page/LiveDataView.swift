//
//  LiveDataView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI
import CoreLocation
import MapKit

struct LiveDataView: View {
    @State private var inputedMake: String = "Mazda"
    @State private var inputedModel: String = "RX7 FC"
    @State private var inputedYear: String = "1991"
    let vehicles = ["RX7 FC", "240SX", "350z"]
    @State private var showRecording = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Live Data")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Resume Last Recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Resume Last Recording
                    Button {
                        showRecording = true
                    } label: {
                        ResumeRecordingCard()
                    }
                    
                    Text("Start New Recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Location Info
                    LocationCard()
                    
                    // Vehicle Selection
                    VehicleInputCard()
                    
                    Button("Start Recording") {
                        showRecording = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            UITabBar.appearance().isHidden = false
        }
        .onDisappear {
            UITabBar.appearance().isHidden = true
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView()
        }
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

struct VehicleInputCard: View {
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""

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
            Text("Location")
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
        manager.distanceFilter = 10          // meters; avoids constant updates
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
