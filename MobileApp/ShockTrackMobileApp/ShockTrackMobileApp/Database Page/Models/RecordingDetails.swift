//
//  Recording.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-10-28.
//


import FirebaseFirestore

struct RecordingDetails: Identifiable, Codable {
    @DocumentID var id: String?
    var vehicle_make: String
    var vehicle_model: String
    var vehicle_year: Int
    var location: GeoPoint? // Raw GPS coordinates
    var locationName: String? // Name based on coordinates
    var duration: Double?
    var fileLink: String?
    @ServerTimestamp var recordedAt: Date?  // Timestamp
}
