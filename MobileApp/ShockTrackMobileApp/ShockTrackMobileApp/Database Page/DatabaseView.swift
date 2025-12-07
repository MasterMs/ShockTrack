//
//  DatabaseView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI

struct DatabaseView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Database")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Previous Recordings Section
                    SectionHeader(title: "Previous Recordings")
                    VStack(spacing: 12) {
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "240SX", subtitle: "Database", date: "Sat, Sept 26th, 2025", image: "240SX")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "RX7", subtitle: "Database", date: "Mon, Sept 29th, 2025", image: "RX7")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "S13", subtitle: "Database", date: "Thu, Oct 9th, 2025", image: "S13")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "GT86", subtitle: "Database", date: "Tue, Oct 21st, 2025", image: "GT86")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "RX7", subtitle: "Database", date: "Wed, Nov 5th, 2025", image: "RX7")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "240SX", subtitle: "Database", date: "Fri, Nov 29th, 2025", image: "240SX")
                        }
                        NavigationLink(destination: DatabaseDetailsView()) {
                            CardView(title: "S13", subtitle: "Database", date: "Fri, Dec 12th, 2025", image: "S13")
                        }
                    }
                }
            }.padding(.horizontal)
        }
    }
}

#Preview {
    DatabaseView()
}
