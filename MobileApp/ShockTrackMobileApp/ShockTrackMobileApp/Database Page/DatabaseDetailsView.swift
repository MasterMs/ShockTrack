//
//  DatabaseDetailsView.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2025-12-07.
//

import SwiftUI

struct DatabaseDetailsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Vehicle Details")
                    .font(.largeTitle)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Year / Make / Model
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Year").font(.headline)
                        Spacer()
                        Text("1993").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Make").font(.headline)
                        Spacer()
                        Text("Nissan").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Model").font(.headline)
                        Spacer()
                        Text("240SX").foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Recording metadata
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text("Long Beach, CA, USA")
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Recorded on Sat, Sept 26th, 2025 • 2:37 PM")
                        Spacer()
                        
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Additional car details (dummy)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specifications")
                        .font(.headline)

                    DetailRow(label: "Trim", value: "SE (S13)")
                    DetailRow(label: "Engine", value: "KA24DE 2.4L I4")
                    DetailRow(label: "Drivetrain", value: "RWD")
                    DetailRow(label: "Transmission", value: "5-speed manual")
                    DetailRow(label: "Suspension", value: "Coilovers • Street/Track tune")
                    DetailRow(label: "Notes", value: "Baseline run after alignment; mild camber front, neutral rear.")
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Graph image at bottom
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording")
                        .font(.headline)
                    NavigationLink(destination: RecordingPlaybackView()) {
                        HStack {
                            Image("Graph")
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .accessibilityLabel("Data graph")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.trailing, 16)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("240SX Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        DatabaseDetailsView()
    }
}
