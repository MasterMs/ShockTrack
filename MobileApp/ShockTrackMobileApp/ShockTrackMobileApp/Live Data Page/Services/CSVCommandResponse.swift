//
//  CSVCommandResponse.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-11-09.
//


import Foundation

struct CSVCommandResponse: Decodable {
    let recording: Bool
    let filepath: String?
    let public_url: String?     // only sent by /stopCSV
    let message: String?
}

enum SensorServerClient {
    // On a real phone, 127.0.0.1 is the phone itself. Use the server's LAN IP there.
    static let baseURL = URL(string: "http://127.0.0.1:8000")!

    static func startCSV() async -> CSVCommandResponse? { await send("startCSV") }
    static func stopCSV() async -> CSVCommandResponse? { await send("stopCSV") }

    private static func send(_ command: String) async -> CSVCommandResponse? {
        var request = URLRequest(url: baseURL.appendingPathComponent(command))
        request.httpMethod = "POST"          
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("[SensorServer] /\(command) returned a non-2xx status")
                return nil
            }
            return try JSONDecoder().decode(CSVCommandResponse.self, from: data)
        } catch {
            print("[SensorServer] /\(command) failed: \(error)")
            return nil
        }
    }
}
