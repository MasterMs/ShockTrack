//
//  DatabaseView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI

struct DatabaseView: View {

    @StateObject private var vm = DatabaseViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Database")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Previous Recordings Section
                    SectionHeader(title: "Previous Recordings")

                    if !vm.recordings.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.recordings) { rec in
                                RecordingRow(recording: rec)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            }
                        }
                    } else if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let msg = vm.errorMessage {
                        Text(msg).foregroundStyle(.red)
                    } else {
                        ContentUnavailableView("No recordings yet", systemImage: "waveform")
                    }
                }
            }
            .padding(.horizontal)
            .refreshable { await vm.load() }
            .onAppear { Task { await vm.load() } }
        }
    }
}

struct RecordingRow: View {
    let recording: RecordingDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(String(recording.vehicle_year)) \(recording.vehicle_make) \(recording.vehicle_model)")
                .font(.headline)

            if let name = recording.locationName {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let date = recording.recordedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                }
                if let seconds = recording.duration {
                    Text("·")
                    Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DatabaseView()
}
