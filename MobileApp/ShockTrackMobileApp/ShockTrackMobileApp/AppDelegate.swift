//
//  AppDelegate.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-11-17.
//


import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait // Default
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        
        return AppDelegate.orientationLock
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      // Forward the URL to Google Sign-In SDK
      return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [ UIApplication.LaunchOptionsKey: Any ]?) -> Bool {
        
        FirebaseApp.configure()
        
        return true
    }
}

