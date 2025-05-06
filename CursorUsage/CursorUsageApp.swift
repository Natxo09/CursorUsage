//
//  CursorUsageApp.swift
//  CursorUsage
//
//  Created by Ignacio Palacio  on 25/4/25.
//

import SwiftUI

@main
struct CursorUsageApp: App {
    // Create the ViewModel and keep it alive for the app's lifecycle
    @StateObject private var viewModel = UsageViewModel()
    
    // We no longer need this state - we'll use the WindowGroup's environment instead
    // @State private var showSettingsWindow = false

    // Helper function to format currency
    private func formatCurrency(_ value: Double?) -> String {
        guard let value = value else { return "$?.??" }
        return String(format: "$%.2f", value)
    }
    
    // Determine what to display in the menu bar
    private var menuBarText: String {
        let premiumUsed = viewModel.usageData.premiumUsed ?? 0
        let premiumLimit = viewModel.usageData.premiumLimit ?? 500
        
        // If we haven't reached the premium limit, show numRequests
        if premiumUsed < premiumLimit {
            return "\(premiumUsed)/\(premiumLimit)"
        } 
        // Otherwise, show the current usage amount
        else {
            return formatCurrency(viewModel.usageData.currentUsage)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            // Pass the ViewModel to the ContentView along with the OpenWindowAction
            ContentView(viewModel: viewModel)
        } label: {
            // Show either requests count or current usage based on the premium limit
            Text(menuBarText)
                .font(.system(size: 12, weight: .medium))
        }
        .menuBarExtraStyle(.window) // Explicitly set the style
        
        // Add a separate window for settings as a WindowGroup
        WindowGroup(id: "settings", for: Bool.self) { _ in
            SettingsView(scraper: viewModel.scraper)
                .onDisappear {
                    // If authentication was successful, refresh data
                    if viewModel.scraper.validationResult?.success == true {
                        viewModel.fetchData()
                    }
                }
        }
        .defaultSize(width: 450, height: 550) // Updated to match new SettingsView size
        .windowResizability(.contentSize)
        .keyboardShortcut(",", modifiers: .command)
        .defaultPosition(.center)
    }
}
