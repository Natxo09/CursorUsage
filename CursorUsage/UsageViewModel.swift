import SwiftUI
import Combine

@MainActor // Ensure @Published updates happen on the main thread
class UsageViewModel: ObservableObject {

    @Published var usageData: CursorUsageData = .placeholder // Start with placeholder
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var userEmail: String? = nil // Store the authenticated user's email

    // Expose the scraper so we can access it from the ContentView for settings
    let scraper = CursorScraper()
    // Use Combine for the timer
    private var timerSubscription: AnyCancellable? = nil
    private let refreshInterval: TimeInterval = 30 * 60 // 30 minutes

    init() {
        // Initial fetch
        fetchData()
        // Start periodic updates
        startTimer()
    }

    // deinit no longer needs to call stopTimer, Combine handles cancellation
    // deinit {
    //     // stopTimer() // No longer needed
    // }

    func fetchData() {
        // Prevent multiple simultaneous fetches
        guard !isLoading else { return }

        isLoading = true
        lastError = nil // Clear previous error
        
        // Check if we have a cookie first
        if !scraper.hasSavedCookie {
            self.lastError = "Please configure your authentication cookie in Settings"
            self.isLoading = false
            return
        }
        
        Task {
            do {
                // Get current auth status first to update email
                let authRequest = scraper.createAuthenticatedRequest(url: scraper.authMeURL)
                let (authData, authResponse) = try await URLSession.shared.data(for: authRequest)
                
                // Extract email if authentication succeeds
                if let authHttpResponse = authResponse as? HTTPURLResponse, 
                   authHttpResponse.statusCode == 200,
                   let authJson = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
                   let email = authJson["email"] as? String {
                    self.userEmail = email
                }
                
                // Then fetch usage data
                var data = try await scraper.fetchUsageData() // Make data mutable
                
                // After fetching usage data, fetch the hard limit
                do {
                    let hardLimit = try await scraper.fetchHardLimit()
                    data.usageLimit = hardLimit // Set the usageLimit on the fetched data
                    print("Successfully fetched hard limit: \(hardLimit ?? -1)")
                } catch let error as ScrapingError {
                    print("Scraping Error (hard limit): \(error)")
                    self.lastError = "Could not fetch spending limit: \(error.localizedDescription)"
                } catch {
                    print("Unexpected Error (hard limit): \(error.localizedDescription)")
                    self.lastError = "Error fetching spending limit: \(error.localizedDescription)"
                }

                print("DEBUG: === ATTEMPTING TO FETCH MONTHLY INVOICE ( reinstated ) ===") // REINSTATED DEBUG LINE
                // After fetching hard limit, fetch the current month's invoice for currentUsage
                do {
                    let currentUsageFromInvoice = try await scraper.fetchCurrentMonthInvoice()
                    // Only update if the value from invoice is non-nil
                    if let usage = currentUsageFromInvoice {
                        data.currentUsage = usage
                        print("Successfully updated currentUsage from monthly invoice: \(usage)")
                    } else {
                        print("Monthly invoice did not provide a currentUsage value or 'items' array. currentUsage remains as is (or nil).")
                        // If data.currentUsage was supposed to come *only* from here, consider setting to 0.0 or handling as an error.
                        // For now, it will retain any value it might have had from /api/usage if that field ever exists, or nil.
                    }
                } catch let error as ScrapingError {
                    print("Scraping Error (monthly invoice): \(error)")
                    self.lastError = "Failed to retrieve current usage from invoice: \(error.localizedDescription)"
                } catch {
                    print("Unexpected Error (monthly invoice): \(error.localizedDescription)")
                    self.lastError = "An unexpected error occurred while fetching current usage from invoice: \(error.localizedDescription)"
                }
                
                // The following calculation might be redundant if the invoice is the source of truth for currentUsage.
                // We will leave it for now but comment it out if invoice data is consistently available and preferred.
                // data.currentUsage = data.calculateCurrentUsage()
                // print("Calculated current usage (potentially overridden by invoice): \(data.currentUsage ?? -1)")

                self.usageData = data
                self.lastUpdated = Date()
                print("Successfully fetched and combined usage data with hard limit.") // Debug log
            } catch let error as ScrapingError {
                // Handle specific scraping errors
                switch error {
                    case .authenticationError:
                        self.lastError = "Authentication required. Please log in to Cursor."
                    case .networkError(let netError):
                        self.lastError = "Network error: \(netError.localizedDescription)"
                    case .parsingError(let msg):
                        self.lastError = "Parsing error: \(msg)"
                    case .dataExtractionError(let msg):
                        self.lastError = "Data extraction error: \(msg)"
                    case .apiError(let msg):
                        self.lastError = "API error: \(msg)"
                }
                print("Scraping Error: \(self.lastError ?? "Unknown scraping error")") // Debug log
                // Optionally keep stale data or reset to placeholder
                 self.usageData = .placeholder // Reset on error for now
            } catch {
                // Handle other unexpected errors
                self.lastError = "An unexpected error occurred: \(error.localizedDescription)"
                print("Unexpected Error: \(self.lastError!)") // Debug log
                self.usageData = .placeholder // Reset on error
            }
            self.isLoading = false
        }
    }

    private func startTimer() {
        // Cancel previous subscription if any
        timerSubscription?.cancel()

        // Schedule new timer using Combine
        timerSubscription = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect() // Starts the timer immediately
            .sink { [weak self] _ in // Use sink to perform action on each emission
                print("Timer fired (Combine). Fetching data...") // Debug log
                self?.fetchData()
            }
    }

    // No explicit stopTimer needed, Combine handles cancellation via AnyCancellable
    // private func stopTimer() { ... } 
} 