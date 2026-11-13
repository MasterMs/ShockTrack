//
//  LiveSessionViewer.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-11-09.
//

import SwiftUI
import MapKit
import FirebaseDatabase
internal import FirebaseAuth

@Observable
final class LiveSessionViewer {
    enum Status { case connecting, live, ended }

    private(set) var status: Status = .connecting
    private(set) var title: String?
    private(set) var kph = 0
    private(set) var direction = "N"
    private(set) var coordinate: CLLocationCoordinate2D?
    var trail: [CLLocationCoordinate2D] = []
    var cameraPosition: MapCameraPosition = .automatic

    @ObservationIgnored private var observers: [(DatabaseReference, DatabaseHandle)] = []

    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else { status = .ended; return }
        let base = Database.database().reference(withPath: "live/\(uid)")

        observe(base.child("status")) { [weak self] snap in
            guard let self else { return }
            if let d = snap.value as? [String: Any], d["active"] as? Bool == true {
                status = .live
                title = d["title"] as? String
            } else {
                status = .ended
            }
        }

        observe(base.child("gps")) { [weak self] snap in
            guard let self,
                  let d = snap.value as? [String: Any],
                  let lat = (d["lat"] as? NSNumber)?.doubleValue,
                  let lon = (d["lon"] as? NSNumber)?.doubleValue else { return }
            let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            kph = (d["kph"] as? NSNumber)?.intValue ?? 0
            direction = d["dir"] as? String ?? direction
            coordinate = c
            trail.append(c)
            if trail.count > 200 { trail.removeFirst(trail.count - 200) }
            let span = Self.zoomSpan(forKPH: Double(kph))
            cameraPosition = .region(MKCoordinateRegion(
                center: c, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))
        }
    }

    func stop() {
        for (ref, handle) in observers { ref.removeObserver(withHandle: handle) }
        observers.removeAll()
    }

    private func observe(_ ref: DatabaseReference, _ onValue: @escaping (DataSnapshot) -> Void) {
        observers.append((ref, ref.observe(.value, with: onValue)))
    }

    private static func zoomSpan(forKPH kph: Double) -> Double {
        let t = min(max(kph / 120.0, 0.0), 1.0)
        return 0.003 + (0.02 - 0.003) * t
    }
}
