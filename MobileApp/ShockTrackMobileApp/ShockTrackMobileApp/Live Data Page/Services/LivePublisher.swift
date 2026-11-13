//
//  LivePublisher.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-11-09.
//

import Foundation
import CoreLocation
import UIKit
import FirebaseDatabase
internal import FirebaseAuth

// Publishes "a recording is live" plus GPS telemetry to live/{uid} so another device can watch.
final class LivePublisher {
    private var base: DatabaseReference?

    func start(title: String) {
        guard base == nil, let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference(withPath: "live/\(uid)")
        base = ref
        ref.onDisconnectRemoveValue()      // if this phone drops off, the viewer sees "ended"
        ref.child("status").setValue([
            "active": true,
            "title": title,
            "device": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "startedAt": ServerValue.timestamp()
        ])
    }

    func publish(location: CLLocation, kph: Int, direction: String) {
        base?.child("gps").setValue([
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude,
            "kph": kph,
            "dir": direction,
            "t": ServerValue.timestamp()
        ])
    }

    func stop() {
        guard let ref = base else { return }
        ref.cancelDisconnectOperations()
        ref.removeValue()
        base = nil
    }
}
