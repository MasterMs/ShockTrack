//
//  DatabaseView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI

struct DatabaseView: View {
    let recordings = [
        ("Canal Time Trial Motorsport Park", "May 5, 2023", "2:45 PM"),
        ("Speedway Circuit", "April 20, 2023", "1:30 PM")
    ]

    var body: some View {
        List(recordings, id: \.0) { recording in
            HStack {
                Image("track_thumbnail")
                    .resizable()
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                VStack(alignment: .leading) {
                    Text(recording.0).font(.headline)
                    Text("\(recording.1) • \(recording.2)").font(.subheadline)
                }
            }
        }
        .navigationTitle("Previous Recordings")
    }
}
