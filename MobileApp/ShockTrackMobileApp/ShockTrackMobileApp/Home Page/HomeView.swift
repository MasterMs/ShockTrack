//
//  HomeView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI
import FirebaseAuthSwiftUI
internal import FirebaseAuth

struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(AuthService.self) private var authService
    @State private var vm = CommunityPostsViewModel()
    @StateObject private var recentDB = DatabaseViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Welcome Back\(firstName.map { " \($0)" } ?? "")")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Live Data Section
                    SectionHeader(title: "Jump Back In")
                    Button {
                        selectedTab = 1 // Live Data Tab
                    } label: {
                        CardView(title: "Start New Recording", subtitle: "Recording", date: getCustomFormattedDate(from: Date()), image: "Recording")
                    }
                    
                    // Database Section
                    SectionHeader(title: "Recent Recordings")
                    VStack(spacing: 12) {
                        if recentDB.recordings.isEmpty {
                            Text(recentDB.isLoading ? "Loading…" : "No recordings yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(recentDB.recordings) { rec in
                                Button {
                                    selectedTab = 3 // Database tab
                                } label: {
                                    CardView(
                                        title: "\(rec.vehicle_make) \(rec.vehicle_model)",
                                        subtitle: rec.locationName ?? "Database",
                                        date: dateText(rec.recordedAt),
                                        image: "Graph"
                                    )
                                }
                            }
                        }
                    }
                    
                    // Community Posts Section
                    SectionHeader(title: "New Community Posts")
                    ForEach(vm.posts.prefix(3)) { post in
                        CommunityPostCard(post: post)
                    }
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        authService.isPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Account")
                }
            }
        }
        .onAppear {
            // Gets Community Posts on Home screen load
            vm.start()
            // Gets Database entries on Home screen load
            Task { await recentDB.load(limit: 3) }
        }
        .onDisappear {
            // Stops loading community posts on clicking off home screen
            vm.stop()
        }
    }
    
    private var firstName: String? {
        guard let displayName = authService.currentUser?.displayName, !displayName.isEmpty else { return nil }
        let parts = displayName.split(separator: " ")
        return parts.first.map(String.init)
    }
    
    private func dateText(_ date: Date?) -> String {
        date?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()) ?? ""
    }
}

// MARK: - Components

func getCustomFormattedDate(from date: Date = .now) -> String {
    let calendar = Calendar.current
    let day = calendar.component(.day, from: date)
    
    // Determine the correct ordinal suffix (st, nd, rd, th)
    let suffix: String
    switch day {
    case 1, 21, 31: suffix = "st"
    case 2, 22:     suffix = "nd"
    case 3, 23:     suffix = "rd"
    default:        suffix = "th"
    }
    
    // Format the Day of Week and Month (e.g., "Saturday, December ")
    let dateEncoding = DateFormatter()
    dateEncoding.dateFormat = "EEEE, MMMM "
    let monthAndDay = dateEncoding.string(from: date)
    
    // Format the Time in lowercase (e.g., "2:48pm")
    let timeEncoding = DateFormatter()
    timeEncoding.dateFormat = "h:mma"
    let timeString = timeEncoding.string(from: date).lowercased()
    
    // Combine them all together
    return "\(monthAndDay)\(day)\(suffix), \(timeString)"
}

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
    
    @Environment(AuthService.self) private var authService
    
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
/*
 #Preview {
    MainTabView()
 }
 */
 
