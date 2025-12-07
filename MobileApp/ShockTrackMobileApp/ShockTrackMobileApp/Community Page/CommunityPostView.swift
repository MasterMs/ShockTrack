//
//  PostView.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2025-12-07.
//

import SwiftUI

struct CommunityPostView: View {
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("S13 Drift Tune")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Image
                    Image("S13")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .accessibilityLabel("Nissan Silvia S13")

                    // Description
                    Text("The Nissan Silvia S13 is a beloved platform in the drifting community thanks to its balanced chassis, lightweight construction, and responsive handling. This tune focuses on predictable oversteer, improved throttle control, and stable transitions. Upgraded suspension geometry, optimized damping, and a limited-slip differential help maintain grip while allowing smooth, controllable slides. Ideal for technical courses and flowing circuits alike.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }

            // Bottom button pinned below the scrollable content
            Button(action: {}) {
                Text("Download Tune")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationView {
        CommunityPostView()
    }
}
