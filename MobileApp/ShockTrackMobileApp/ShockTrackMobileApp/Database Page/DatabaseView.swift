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
                }
            }.padding(.horizontal)
        }
    }
}

#Preview {
    DatabaseView()
}
