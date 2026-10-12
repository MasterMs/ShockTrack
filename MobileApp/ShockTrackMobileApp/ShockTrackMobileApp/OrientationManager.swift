//
//  OrientationManager.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-10-12.
//


import UIKit

enum OrientationManager {
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? 
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }

        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            print("Orientation update failed: \(error)")
        }
    }
}