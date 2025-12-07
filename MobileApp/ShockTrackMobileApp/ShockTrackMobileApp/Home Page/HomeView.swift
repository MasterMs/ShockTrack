//
//  HomeView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Live Data Section
                    SectionHeader(title: "Jump Back In")
                    Button {
                        selectedTab = 1 // Live Data Tab
                    } label: {
                        CardView(title: "RX7", subtitle: "Live Data", date: "Thursday, Oct 2nd, 2025", image: "RX7")
                    }
                    
                    // Database Section
                    SectionHeader(title: "Database")
                    VStack(spacing: 12) {
                        Button {
                            selectedTab = 3 // Database tab
                        } label: {
                            CardView(title: "240SX", subtitle: "Database", date: "Sat, Sept 26th, 2025", image: "240SX")
                        }
                        Button {
                            selectedTab = 3 // Database tab
                        } label: {
                            CardView(title: "RX7", subtitle: "Database", date: "Mon, Sept 29th, 2025", image: "RX7")
                        }
                    }
                    
                    // Community Posts Section
                    SectionHeader(title: "New Community Posts")
                    VStack(spacing: 20) {
                        Button {
                            selectedTab = 2 // Community tab
                        } label: {
                            PostView(title: "Drift 240SX Setup", views: "6473", image: "240SX")
                        }
                        Button {
                            selectedTab = 2 // Community tab
                        } label: {
                            PostView(title: "RX7 Drift Clip", views: "2483", image: "RX7")
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Components

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, 4)
    }
}

struct CardView: View {
    let title: String
    let subtitle: String
    let date: String
    let image: String
    
    var body: some View {
        HStack {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 60)
                .cornerRadius(8)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.label))
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 30)
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

struct PostView: View {
    let title: String
    let views: String
    let image: String

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .bottomLeading) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: 370)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.white)
                                    Text(views)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                            }
                            Spacer()
                        }
                        .padding([.top, .trailing], 8),
                        alignment: .topTrailing
                    )

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding([.leading, .bottom], 8)
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            LiveDataView()
                .tabItem {
                    Label("Live Data", systemImage: "waveform.path.ecg")
                }
                .tag(1)

            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .tag(2)

            DatabaseView()
                .tabItem {
                    Label("Database", systemImage: "archivebox.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
}
