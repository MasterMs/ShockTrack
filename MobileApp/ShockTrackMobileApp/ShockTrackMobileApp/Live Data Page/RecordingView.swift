//
//  RecordingView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-11-17.
//

import SwiftUI
import Charts

struct GraphSample: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
}

@Observable
final class DummyGraphModel {
    var samples: [GraphSample] = []
    private var timer: Timer?
    private var currentValue: Double = 50
    private let maxCount: Int = 120 // ~30s at 0.25s interval

    private var i: Int = 0
    private let amplitude: Double = 80
    private let frequency: Double = 1.0
    private let dt: Double = 0.02
    private var t: Double = 0
    private var isRunning: Bool = false

    func start() {
        stop()
        if samples.isEmpty {
            samples = (0..<40).map { GraphSample(index: $0, value: 0) }
            i = samples.count
            t = Double(i) * dt
        }
        scheduleTimer()
    }
    
    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func resume() {
        guard !isRunning else { return }
        scheduleTimer()
    }
    
    private func scheduleTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] _ in
            guard let self else { return }
            let sine = amplitude * sin(2 * .pi * frequency * t)
            let jitter = Double.random(in: -4...4)
            currentValue = sine + jitter

            samples.append(GraphSample(index: i, value: currentValue))
            i += 1
            t += dt

            if samples.count > maxCount {
                samples.removeFirst(samples.count - maxCount)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

@Observable
final class DummyTelemetryModel {
    var kph: Int = 0
    var direction: String = "N"

    private var timer: Timer?
    private var headingIndex: Int = 0
    private let headings = ["N","NE","E","SE","S","SW","W","NW"]
    private var currentSpeed: Double = 50

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Smoothly vary speed with small random steps and clamp 0...180
            let step = Double.random(in: -5...5)
            currentSpeed = max(0, min(180, currentSpeed + step))
            kph = Int(currentSpeed.rounded())

            // Rotate heading every tick
            headingIndex = (headingIndex + 1) % headings.count
            direction = headings[headingIndex]
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct RecordingView: View {
    @State private var telemetry = DummyTelemetryModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            Group {
                if isLandscape {
                    LandscapeLayout(kph: telemetry.kph, direction: telemetry.direction)
                        .toolbar(.hidden, for: .tabBar)
                } else {
                    PortraitLayout(kph: telemetry.kph, direction: telemetry.direction)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                telemetry.start()
            }
            .onDisappear { telemetry.stop() }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

#Preview {
    RecordingView()
}

// MARK: - Landscape
struct LandscapeLayout: View {
    let kph: Int
    let direction: String
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                // Left: Graph
                GraphView()
                    .frame(width: UIScreen.main.bounds.width * 0.6)
                
                // Right: Speed + Compass
                VStack(spacing: 30) {
                    SpeedDisplay(kph: kph)
                    CompassDisplay(direction: direction)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            
            Button("Stop Recording") {
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

// MARK: - Portrait
struct PortraitLayout: View {
    let kph: Int
    let direction: String
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Top: Speed + Compass side-by-side
            HStack(spacing: 30) {
                SpeedDisplay(kph: kph)
                Divider()
                    .frame(height: 48)
                    .background(Color.white.opacity(0.3))
                CompassDisplay(direction: direction)
            }
            .padding(.horizontal)

            // Bottom: Graph fills remaining space
            GraphView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Button("Stop Recording") {
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - Components
struct GraphView: View {
    var isPlaying: Bool = true
    @State private var model = DummyGraphModel()

    var body: some View {
        let count = model.samples.count
        let xMax = (model.samples.last?.index ?? 0)
        let window = max(60, min(240, model.samples.count)) // keep 3–12 seconds visible depending on rate
        let xMin = max(0, xMax - window)

        return Chart(model.samples) { point in
            LineMark(
                x: .value("Index", point.index),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.linear)
        }
        .chartXScale(domain: xMin...xMax)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(domain: -100...100)
        .onAppear {
            if isPlaying {
                model.start()
            } else {
                model.start()
                model.pause()
            }
        }
        .onDisappear { model.stop() }
        .onChange(of: isPlaying) { _, playing in
            if playing { model.resume() } else { model.pause() }
        }
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SpeedDisplay: View {
    let kph: Int

    var body: some View {
        VStack {
            Text("\(kph)")
                .font(.system(size: 64, weight: .bold))
            Text("KPH")
                .font(.title2)
                .opacity(0.9)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct CompassDisplay: View {
    let direction: String

    var body: some View {
        VStack {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 40))
            Text(direction)
                .font(.title2)
                .opacity(0.9)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
