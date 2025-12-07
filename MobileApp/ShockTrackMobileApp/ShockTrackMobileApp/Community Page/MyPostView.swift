//
//  PostView.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2025-12-07.
//

import SwiftUI

struct MyPostView: View {
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("RUTU Shock Setup")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Image
                    Image("SuspImg2")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .accessibilityLabel("Nissan Silvia S13")

                    // Description
                    Text("Dialed-in suspension that balances comfort and control for spirited driving. This tune pairs firmer spring rates with progressive damping to keep the chassis planted over mid-corner bumps while maintaining quick weight transfer for rotation. Slightly increased front rebound sharpens turn-in, while a touch more rear compression improves traction on exit. Ideal for weekend canyon runs and track days without sacrificing daily drivability.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }

            // Bottom button pinned below the scrollable content
            Button(action: {}) {
                Text("Edit Post")
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
        MyPostView()
    }
}
