//
//  LiveViewerView.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-11-09.
//

import SwiftUI
import UIKit
import StoreKit
import RealityKit

struct LiveViewerView: View {
    @State private var viewer = LiveSessionViewer()
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
            .navigationTitle(viewer.title ?? "Live Recording")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Live")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.red))
                        .foregroundColor(.white)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .overlay {
                switch viewer.status {
                case .connecting:
                    ProgressView("Connecting…").tint(.white).foregroundColor(.white)
                case .ended:
                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Text("This recording has ended").font(.title2).foregroundColor(.white)
                            Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                        }
                    }
                case .live:
                    EmptyView()
                }
            }
            .onAppear {
                OrientationManager.set(.allButUpsideDown)
                viewer.start()
            }
            .onDisappear {
                OrientationManager.set(.portrait)
                viewer.stop()
            }
        }
    }

    @ViewBuilder
    private func layout(for size: CGSize) -> some View {
        if size.width > size.height {
            LandscapeLayout(kph: viewer.kph, direction: viewer.direction,
                            isUploading: .constant(false), isFakeSensorData: .constant(false),
                            cameraPosition: $viewer.cameraPosition, trail: $viewer.trail,
                            isSaving: false, onStop: { dismiss() },
                            remoteCoordinate: viewer.coordinate, stopTitle: "Leave")
        } else {
            PortraitLayout(kph: viewer.kph, direction: viewer.direction,
                           isConnected: .constant(false), isUploading: .constant(false),
                           isFakeSensorData: .constant(false),
                           cameraPosition: $viewer.cameraPosition, trail: $viewer.trail,
                           isSaving: false, onStop: { dismiss() },
                           remoteCoordinate: viewer.coordinate, stopTitle: "Leave")
        }
    }
}
