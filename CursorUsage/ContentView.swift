//
//  ContentView.swift
//  CursorUsage
//
//  Created by Ignacio Palacio  on 25/4/25.
//

import SwiftUI

struct ContentView: View {
    // Receive the ViewModel from the App
    @ObservedObject var viewModel: UsageViewModel
    
    // Use environment to open windows
    @Environment(\.openWindow) private var openWindow
    
    // Timer to auto-dismiss error messages
    @State private var errorTimer: Timer?
    
    // Debug: Print data when it changes
    var debugDataDescription: String {
        let data = viewModel.usageData
        return """
        Debug Data:
        - refreshDays: \(data.refreshDays)
        - premiumUsed: \(data.premiumUsed)
        - premiumLimit: \(data.premiumLimit)
        - fastUsed: \(data.fastUsed)
        - currentUsage: \(data.currentUsage)
        - usageLimit: \(data.usageLimit)
        """
    }

    var body: some View {
        ZStack {
            // Contenido principal
            VStack(alignment: .leading, spacing: 15) {
                // Print debug info when data changes
                let _ = print(debugDataDescription)
                
                // Header with Account Information and Buttons
                HStack(alignment: .center) {
                    // Account Information
                    if let email = viewModel.userEmail {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text(email)
                                .font(.headline)
                            
                            // Subscription badges
                            HStack(spacing: 5) {
                                // Pro badge with gold/yellow color
                                if viewModel.scraper.subscriptionData.membershipType?.lowercased() == "pro" {
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow.opacity(0.3))
                                        .foregroundColor(Color.orange)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.yellow, lineWidth: 1)
                                        )
                                } else if viewModel.scraper.subscriptionData.membershipType?.lowercased() == "free" {
                                    Text("FREE")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(Color.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                }
                                
                                // Subscription status badge
                                if let status = viewModel.scraper.subscriptionData.subscriptionStatus {
                                    let isActive = status.lowercased() == "active"
                                    Text(status.capitalized)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isActive ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        .foregroundColor(isActive ? .green : .orange)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Control Buttons
                    HStack(spacing: 12) {
                        // Refresh Button
                        Button {
                            viewModel.fetchData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // Settings Button
                        Button {
                            openWindow(id: "settings", value: true)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // Close/Exit Button
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.bottom, 5)
                Divider()
                
                // Display Loading State
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .foregroundColor(.gray)
                    }
                }

                // Display Last Updated Time
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Last updated: \(lastUpdated, style: .time)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                // Display Error Message - Enhanced visibility and auto-dismiss
                if let errorMsg = viewModel.lastError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                        
                        Text(errorMsg)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        Button {
                            viewModel.lastError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.vertical, 5)
                    .onAppear {
                        // Set timer to dismiss error after 10 seconds
                        errorTimer?.invalidate()
                        errorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                            viewModel.lastError = nil
                        }
                    }
                    .onDisappear {
                        errorTimer?.invalidate()
                        errorTimer = nil
                    }
                }

                // --- Use data from ViewModel --- 
                // Refresh Info
                Text("Fast requests will refresh in \(viewModel.usageData.refreshDays != nil ? String(viewModel.usageData.refreshDays!) : "?") days")
                    .font(.headline)
                    .padding(.bottom, 5)

                // Replace HStack with VStack for vertical layout
                VStack(spacing: 15) {
                    // Premium Models Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Premium models")
                                .font(.headline)
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(viewModel.usageData.premiumUsed != nil ? String(viewModel.usageData.premiumUsed!) : "?") / \(viewModel.usageData.premiumLimit != nil ? String(viewModel.usageData.premiumLimit!) : "?")")
                                .fontWeight(.semibold)
                        }
                        
                        // Progress bar - handle nil or zero limit
                        let premiumProgress = calculateProgress(used: viewModel.usageData.premiumUsed, limit: viewModel.usageData.premiumLimit)
                        ProgressView(value: premiumProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: premiumProgress >= 1.0 ? .red : .blue))
                            .padding(.vertical, 5)

                        // Additional usage info
                        HStack {
                            // Description Text (Update based on data)
                            Text(premiumDescription)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            // Usage percentage
                            if let used = viewModel.usageData.premiumUsed, let limit = viewModel.usageData.premiumLimit, limit > 0 {
                                Text("\(Int(Double(used) / Double(limit) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(premiumProgress >= 0.9 ? .red : .primary)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)

                    // Fast Models Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("gpt-4o-mini or cursor-small")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.usageData.fastUsed != nil ? String(viewModel.usageData.fastUsed!) : "?") / No Limit")
                                .fontWeight(.semibold)
                        }

                        // Always full for unlimited?
                        ProgressView(value: 1.0) 
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .padding(.vertical, 5)

                        Text("You've used \(viewModel.usageData.fastUsed != nil ? String(viewModel.usageData.fastUsed!) : "?") fast requests of this model. You have no monthly quota.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)

                    // Current Usage Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Usage")
                            .font(.headline)
                        
                        // Progress bar for current usage
                        let usageProgress = calculateProgress(
                            used: viewModel.usageData.currentUsage, 
                            limit: viewModel.usageData.usageLimit
                        )
                        
                        HStack(alignment: .center) {
                            Text("$\(formatCurrency(viewModel.usageData.currentUsage))")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("of $\(formatCurrency(viewModel.usageData.usageLimit)) limit")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        ProgressView(value: usageProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: 
                                usageProgress < 0.7 ? .green : 
                                usageProgress < 0.9 ? .yellow : .red
                            ))
                            .padding(.vertical, 5)
                        
                        // Remaining amount
                        if let limit = viewModel.usageData.usageLimit, let current = viewModel.usageData.currentUsage {
                            let remaining = limit - current
                            HStack {
                                Text("Remaining: $\(formatCurrency(remaining > 0 ? remaining : 0))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Usage percentage
                                Text("\(Int(usageProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(
                                        usageProgress < 0.7 ? .green : 
                                        usageProgress < 0.9 ? .yellow : .red
                                    )
                                    .fontWeight(.bold)
                            }
                        }
                        Divider()
                            .padding(.vertical, 5)
                            
                        // Get values from the model
                        let totalRequests = viewModel.usageData.getTotalRequests()
                        
                        // Calculate maximum requests based on usage limit and base Pro allowance
                        if let usageLimitInDollars = viewModel.usageData.usageLimit {
                            let baseProRequests = viewModel.usageData.premiumLimit ?? 0 // Base 500 requests for Pro
                            
                            // Calculate how many ADDITIONAL requests the usageLimitInDollars can buy
                            // Cost is $0.04 per additional request
                            let additionalRequestsFromLimit = Int(usageLimitInDollars / 0.04)
                            
                            // Total maximum possible requests
                            let maxPossibleRequests = baseProRequests + additionalRequestsFromLimit
                            
                            let remainingRequests = maxPossibleRequests - totalRequests
                            
                            Text("Total Requests")
                                .font(.headline)
                                .padding(.bottom, 2)
                            
                            HStack {
                                Text("\(totalRequests)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Text("of \(maxPossibleRequests) requests")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            
                            // Progress bar for requests
                            let requestsProgress = maxPossibleRequests > 0 ? min(Double(totalRequests) / Double(maxPossibleRequests), 1.0) : 0.0
                            ProgressView(value: requestsProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: 
                                    requestsProgress < 0.7 ? .green : 
                                    requestsProgress < 0.9 ? .yellow : .red
                                ))
                                .padding(.vertical, 5)
                            
                            // Remaining requests
                            HStack {
                                Text("Remaining: \(remainingRequests > 0 ? remainingRequests : 0) requests")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Usage percentage
                                Text("\(Int(requestsProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(
                                        requestsProgress < 0.7 ? .green : 
                                        requestsProgress < 0.9 ? .yellow : .red
                                    )
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding()
            .frame(width: 500)
            
            // Overlay de carga con fondo blurreado
            if viewModel.isLoading {
                ZStack {
                    // Fondo blurreado
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .background(Material.ultraThinMaterial.opacity(0.7))
                        .edgesIgnoringSafeArea(.all)
                    
                    // Contenedor de la animación
                    VStack(spacing: 15) {
                        // Círculo de carga animado
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Updating data...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(30)
                    .background(Material.regularMaterial.opacity(0.85))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            }
        }
    }

    // --- Helper function to calculate progress safely ---
    private func calculateProgress(used: Int?, limit: Int?) -> Double {
        guard let used = used, let limit = limit, limit > 0 else {
            return 0.0 // Or 1.0 if used > 0 and limit is 0? Depends on desired display
        }
        return min(Double(used) / Double(limit), 1.0) // Cap at 1.0
    }

    // Overload for double values
    private func calculateProgress(used: Double?, limit: Double?) -> Double {
        guard let used = used, let limit = limit, limit > 0 else {
            return 0.0
        }
        return min(used / limit, 1.0)
    }

    // --- Helper function to format currency ---
    private func formatCurrency(_ value: Double?) -> String {
        guard let value = value else { return "?.??" }
        return String(format: "%.2f", value)
    }
    
    // --- Dynamic description for premium usage ---
    private var premiumDescription: String {
        guard let used = viewModel.usageData.premiumUsed, let limit = viewModel.usageData.premiumLimit else {
            return "Usage data unavailable."
        }
        if used >= limit {
            return "You've hit your limit of \(limit) fast requests"
        }
        return "Used \(used) of \(limit) fast requests."
    }
}

// Add ViewModel to the PreviewProvider for easier design iteration
#Preview {
    ContentView(
        viewModel: {
            let vm = UsageViewModel()
            // Optionally set example data directly for preview
            // vm.usageData = CursorUsageData.example
            return vm
        }()
    )
}
