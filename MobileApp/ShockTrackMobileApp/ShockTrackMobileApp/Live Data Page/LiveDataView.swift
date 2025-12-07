//
//  LiveDataView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI
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
                Image("Graph") // Replace with actual image
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
    
    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.0550, longitude: -78.6750),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Location")
                .font(.headline)
            Map(coordinateRegion: .constant(region), interactionModes: [.all])
                .frame(width: 300, height: 170)
                .cornerRadius(8)
            Text("Canadian Tire Motorsport Park")
                .font(.subheadline)
                .frame(alignment: .center)
            Text("Bowmanville, ON")
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
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
