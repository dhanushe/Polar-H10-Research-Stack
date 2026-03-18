//
//  MainTabView.swift
//  URAP Polar H10 V1
//
//  Custom floating tab bar navigation
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationView {
                    DashboardView()
                }
                .navigationViewStyle(.stack)
                .tag(0)

                NavigationView {
                    RecordingsListView()
                }
                .navigationViewStyle(.stack)
                .tag(1)

                NavigationView {
                    SettingsView()
                }
                .navigationViewStyle(.stack)
                .tag(2)
            }
            .toolbar(.hidden, for: .tabBar)
            .ignoresSafeArea(edges: .bottom)

            CustomFloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
}
