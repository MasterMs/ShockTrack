//
//  SocketView.swift
//  ShockTrack
//
//  Created by Marco Siciliano on 2026-10-03.
//

import SwiftUI
import Charts

struct SensorData: Codable {
    let accel_x: Double
    let accel_y: Double
    let accel_z: Double
    let gyro_x: Double
    let gyro_y: Double
    let gyro_z: Double
}

struct GraphPoint: Identifiable {
    let id = UUID()
    let index: Int
    let x: Double
    let y: Double
    let z: Double
}

struct SocketView: View {

    @State private var websocketValue: String = "Waiting for data..."
    @State private var isConnected: Bool = false
    @State private var webSocketTask: URLSessionWebSocketTask?

    @State private var sensorData: SensorData?

    @State private var graphData: [GraphPoint] = []
    @State private var sampleIndex: Int = 0

    var body: some View {

        VStack(spacing: 20) {

            Text("WebSocket Data")
                .font(.largeTitle)
                .bold()

            Text(isConnected ? "Connected" : "Disconnected")
                .foregroundStyle(isConnected ? .green : .red)

            if let sensor = sensorData {

                HStack(spacing: 30) {

                    VStack {
                        Text("Accel X")
                        Text(String(format: "%.2f", sensor.accel_x))
                            .font(.title2)
                    }

                    VStack {
                        Text("Accel Y")
                        Text(String(format: "%.2f", sensor.accel_y))
                            .font(.title2)
                    }

                    VStack {
                        Text("Accel Z")
                        Text(String(format: "%.2f", sensor.accel_z))
                            .font(.title2)
                    }
                }
            }

            Chart {
                ForEach(graphData) { point in

                    LineMark(
                        x: .value("Sample", point.index),
                        y: .value("Acceleration", point.x)
                    )
                    .foregroundStyle(by: .value("Axis", "X"))

                    LineMark(
                        x: .value("Sample", point.index),
                        y: .value("Acceleration", point.y)
                    )
                    .foregroundStyle(by: .value("Axis", "Y"))

                    LineMark(
                        x: .value("Sample", point.index),
                        y: .value("Acceleration", point.z)
                    )
                    .foregroundStyle(by: .value("Axis", "Z"))
                }
            }
            .chartXScale(
                domain: max(0, sampleIndex - 200)...max(200, sampleIndex)
            )
            .chartYAxisLabel("Acceleration")
            .chartXAxisLabel("Sample")
            .frame(height: 300)
            .padding()

            Button {
                if isConnected {
                    disconnectWebSocket()
                } else {
                    connectWebSocket()
                }
            } label: {
                Text(isConnected ? "Disconnect" : "Connect / Reconnect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            connectWebSocket()
        }
        .onDisappear {
            disconnectWebSocket()
        }
    }

    private func connectWebSocket() {

        webSocketTask?.cancel(
            with: .goingAway,
            reason: nil
        )

        guard let url = URL(string: "ws://192.168.2.12:8000/ws") else {
            return
        }

        let task = URLSession.shared.webSocketTask(with: url)

        webSocketTask = task
        task.resume()

        isConnected = true

        receiveMessage()
    }

    private func receiveMessage() {

        webSocketTask?.receive { result in

            switch result {

            case .success(let message):

                switch message {

                case .string(let text):
                    handleMessage(text)

                case .data(let data):

                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }

                @unknown default:
                    break
                }

                receiveMessage()

            case .failure(let error):

                print("WebSocket error:", error)

                DispatchQueue.main.async {
                    self.isConnected = false
                    self.webSocketTask = nil
                }
            }
        }
    }

    private func handleMessage(_ text: String) {

        let values = text
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

        guard values.count == 6,
              let accelX = Double(values[0]),
              let accelY = Double(values[1]),
              let accelZ = Double(values[2]),
              let gyroX = Double(values[3]),
              let gyroY = Double(values[4]),
              let gyroZ = Double(values[5]) else {

            print("Invalid sensor data:", text)
            return
        }

        let decoded = SensorData(
            accel_x: accelX,
            accel_y: accelY,
            accel_z: accelZ,
            gyro_x: gyroX,
            gyro_y: gyroY,
            gyro_z: gyroZ
        )

        DispatchQueue.main.async {

            websocketValue = text
            sensorData = decoded

            let point = GraphPoint(
                index: sampleIndex,
                x: decoded.accel_x,
                y: decoded.accel_y,
                z: decoded.accel_z
            )

            graphData.append(point)
            sampleIndex += 1

            if graphData.count > 200 {
                graphData.removeFirst()
            }
        }
    }

    private func disconnectWebSocket() {

        webSocketTask?.cancel(
            with: .goingAway,
            reason: nil
        )

        webSocketTask = nil
        isConnected = false
    }
}

#Preview {
    SocketView()
}
