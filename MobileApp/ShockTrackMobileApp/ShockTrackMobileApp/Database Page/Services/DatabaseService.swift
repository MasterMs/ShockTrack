//
//  DatabaseService.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-10-28.
//

internal import FirebaseAuth
import FirebaseFirestore
import _LocationEssentials

enum RecordingError: Error { case notSignedIn }

struct DatabaseService {
    private let db = Firestore.firestore()

    private func collection() throws -> CollectionReference {
        guard let uid = Auth.auth().currentUser?.uid else { throw RecordingError.notSignedIn }
        return db.collection("Recordings").document(uid).collection("recording_details")
    }

    func fetchRecordings() async throws -> [RecordingDetails] {
        let uid = Auth.auth().currentUser?.uid ?? "nil"
        let snapshot = try await collection().order(by: "recordedAt", descending: true).getDocuments()
        //print("[DB] signed-in uid: \(uid), documents found: \(snapshot.documents.count)")

        var results: [RecordingDetails] = []
        for doc in snapshot.documents {
            do {
                results.append(try doc.data(as: RecordingDetails.self))
            } catch {
                //print("[DB] decode failed for \(doc.documentID): \(error)")
            }
        }
        return results.sorted { ($0.recordedAt ?? .distantPast) > ($1.recordedAt ?? .distantPast) }
    }
    
    func delete(_ recording: RecordingDetails) async throws {
        guard let id = recording.id else { return }
        try await collection().document(id).delete()
    }
    
    @discardableResult
    func saveRecording(make: String, model: String, year: Int,
                        location: CLLocation?, duration: TimeInterval) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw RecordingError.notSignedIn }

        let rec = RecordingDetails(
            vehicle_make: make.trimmingCharacters(in: .whitespaces),
            vehicle_model: model.trimmingCharacters(in: .whitespaces),
            vehicle_year: year,
            location: location.map { GeoPoint(latitude: $0.coordinate.latitude,
                                                longitude: $0.coordinate.longitude) },
            duration: duration
        )

        let ref = Firestore.firestore()
            .collection("Recordings").document(uid)
            .collection("recording_details").document()   // auto ID
        try ref.setData(from: rec)
        return ref.documentID
    }
}
