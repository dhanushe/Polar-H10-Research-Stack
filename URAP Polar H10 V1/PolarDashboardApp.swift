//
//  PolarDashboardApp.swift
//  URAP Polar H10 V1
//
//  Created by Dhanush Eashwar on 10/7/25.
//


import SwiftUI

@main
struct PolarDashboardApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var polarManager = PolarManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                print("App entering background - maintaining Bluetooth connections")
                polarManager.handleAppBackground()
                APIServer.shared.stop()
            case .active:
                print("App becoming active - ensuring connections are healthy")
                polarManager.handleAppForeground()
                APIServer.shared.start()
            case .inactive:
                print("App becoming inactive")
            @unknown default:
                break
            }
        }
    }
}