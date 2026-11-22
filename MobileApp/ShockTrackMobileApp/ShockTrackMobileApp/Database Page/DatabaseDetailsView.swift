//
//  DatabaseDetailsView.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2025-12-07.
//

import SwiftUI
import FirebaseFirestore

struct DatabaseDetailsView: View {
    let recording: RecordingDetails

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
                        Text(String(recording.vehicle_year)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Make").font(.headline)
                        Spacer()
                        Text(recording.vehicle_make).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Model").font(.headline)
                        Spacer()
                        Text(recording.vehicle_model).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Recording metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Info")
                        .font(.headline)
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(recording.locationName ?? coordinatesText ?? "Location unavailable")
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(recording.recordedAt?.formatted(date: .abbreviated, time: .shortened)
                             ?? "Date unavailable")
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Recording info (only rows that have data)
                if durationText != nil || coordinatesText != nil || fileName != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recording Info")
                            .font(.headline)

                        if let durationText { DetailRow(label: "Duration", value: durationText) }
                        if let coordinatesText { DetailRow(label: "Coordinates", value: coordinatesText) }
                        if let fileName { DetailRow(label: "Sensor file", value: fileName) }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Graph image at bottom
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording")
                        .font(.headline)

                    if recording.fileLink != nil {
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
                    } else {
                        Text("No sensor file was saved for this recording.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(recording.vehicle_model) Recording Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }

    // MARK: - Formatting

    private var durationText: String? {
        guard let seconds = recording.duration else { return nil }
        let d = Duration.seconds(seconds)
        return seconds >= 3600
            ? d.formatted(.time(pattern: .hourMinuteSecond))
            : d.formatted(.time(pattern: .minuteSecond))
    }

    private var coordinatesText: String? {
        guard let p = recording.location else { return nil }
        return String(format: "%.5f, %.5f", p.latitude, p.longitude)
    }

    private var fileName: String? {
        guard let path = recording.filePath else { return nil }
        return (path as NSString).lastPathComponent
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
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DatabaseDetailsView(recording: RecordingDetails(
            id: nil,
            vehicle_make: "Nissan",
            vehicle_model: "240SX",
            vehicle_year: 1993,
            location: GeoPoint(latitude: 33.7701, longitude: -118.1937),
            locationName: "Long Beach, CA",
            duration: 754,
            recordedAt: Date(),
            fileLink: "https://example.com/run.csv"
        ))
    }
}
