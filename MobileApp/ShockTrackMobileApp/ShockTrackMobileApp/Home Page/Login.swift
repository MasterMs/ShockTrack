//
//  Login.swift
//  ShockTrackMobileApp
//
//  Created by Nicholas Sullivan on 2026-09-25.
//

import FirebaseAppleSwiftUI
import FirebaseAuthSwiftUI
import FirebaseGoogleSwiftUI
import SwiftUI

struct ContentView: View {
  let authService: AuthService

  init() {
    // Create configuration with options
    let configuration = AuthConfiguration(
      //shouldAutoUpgradeAnonymousUsers: true,
      tosUrl: URL(string: "https://example.com/tos"),
      privacyPolicyUrl: URL(string: "https://example.com/privacy")
    )

    // Initialize AuthService with multiple providers
    authService = AuthService(configuration: configuration)
      .withEmailSignIn()
      .withAppleSignIn()
      .withGoogleSignIn()
  }

  var body: some View {
    AuthPickerView {
      authenticatedContent
    }
    .environment(authService)
  }

  var authenticatedContent: some View {
    NavigationStack {
      Group {
        if authService.authenticationState == .authenticated {
          MainTabView()
        } else {
          VStack(spacing: 20) {
            Text("Not Authenticated")
            
            Button("Sign In") {
              authService.isPresented = true
            }
            .buttonStyle(.borderedProminent)
          }
        }
      }
    }
    .onChange(of: authService.authenticationState) { _, newValue in
      // Automatically show auth UI when not authenticated
      if newValue != .authenticating {
        authService.isPresented = (newValue == .unauthenticated)
      }
    }
  }
}
