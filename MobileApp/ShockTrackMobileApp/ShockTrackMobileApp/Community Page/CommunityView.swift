//
//  CommunityView.swift
//  ShockTrack
//
//  Created by Nicholas Sullivan on 2025-10-30.
//

import SwiftUI

struct CommunityView: View {
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Community")
                            .font(.largeTitle)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        SectionHeader(title: "My Posts")
                        ScrollView(.horizontal, showsIndicators: false){
                            HStack {
                                NavigationLink(destination: MyPostView()) {
                                    PostView(title: "RUTU Shock Setup", views:
                                                "3421", image: "SuspImg2")
                                }
                                NavigationLink(destination: MyPostView()) {
                                    PostView(title: "MX5 Shock Setup", views: "1237", image: "SuspensionImg")
                                }
                                NavigationLink(destination: MyPostView()) {
                                    PostView(title: "MR2 Suspension Tune", views: "6391", image: "SuspImg2")
                                }
                            }
                        }
                        
                        SectionHeader(title: "Community Posts")
                        NavigationLink(destination: CommunityPostView()) {
                            PostView(title: "S13 Drift Tune", views: "4109", image: "S13")
                        }
                        NavigationLink(destination: CommunityPostView()) {
                            PostView(title: "GT86 Drift Tune", views: "2483", image: "GT86")
                        }
                        NavigationLink(destination: CommunityPostView()) {
                            PostView(title: "240SX Drift Clip", views: "8292", image: "240SX")
                        }
                    }
                }
                .padding(.horizontal)
                
                // Floating "+" button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: CreatePostView()) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

#Preview {
    CommunityView()
}
