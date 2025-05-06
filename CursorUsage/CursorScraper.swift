import Foundation
import SwiftUI

enum ScrapingError: Error {
    case networkError(Error)
    case parsingError(String)
    case dataExtractionError(String)
    case authenticationError // Specific error if we detect login page
    case apiError(String)    // Added for API errors
}

class CursorScraper: ObservableObject {
    // Constants
    private let cookieNameKey = "WorkosCursorSessionToken"
    private let userDefaultsCookieKey = "cursor_cookie_value"
    
    // URLs
    public let authMeURL = URL(string: "https://www.cursor.com/api/auth/me")!
    private let usageAPIURL = URL(string: "https://www.cursor.com/api/usage")! 
    private let stripeAPIURL = URL(string: "https://www.cursor.com/api/auth/stripe")!
    private let hardLimitAPIURL = URL(string: "https://www.cursor.com/api/dashboard/get-hard-limit")!
    private let monthlyInvoiceAPIURL = URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice")!
    
    // Published properties to observe in the UI
    @Published var isValidating = false
    @Published var validationResult: (success: Bool, message: String)? = nil
    @Published var subscriptionData: CursorSubscriptionData = .placeholder
    
    // Get cookie from UserDefaults, falling back to hardcoded value if not found
    private var cookieValue: String {
        // Try to get from UserDefaults
        if let savedValue = UserDefaults.standard.string(forKey: userDefaultsCookieKey),
           !savedValue.isEmpty {
            return savedValue
        }
        
        // No fallback value - return empty string
        return ""
    }
    
    // Update the cookie value
    func updateCookieValue(_ newValue: String) {
        UserDefaults.standard.set(newValue, forKey: userDefaultsCookieKey)
    }
    
    // Check if a cookie is saved
    var hasSavedCookie: Bool {
        return UserDefaults.standard.string(forKey: userDefaultsCookieKey) != nil
    }
    
    // Function to verify a cookie works by calling auth/me API
    @MainActor // Since it updates @Published properties
    func verifyCookie(_ cookieToVerify: String) async -> Bool {
        // Start validation UI
        isValidating = true
        validationResult = nil
        
        do {
            let request = createAuthenticatedRequest(url: authMeURL, cookieValue: cookieToVerify)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                isValidating = false
                validationResult = (false, "Invalid response type")
                return false
            }
            
            // Check status code
            if httpResponse.statusCode != 200 {
                isValidating = false
                validationResult = (false, "Server returned \(httpResponse.statusCode)")
                return false
            }
            
            // Verify JSON contains user info
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let email = json["email"] as? String {
                isValidating = false
                validationResult = (true, "Authenticated as: \(email)")
                
                // Save this cookie as it's valid
                updateCookieValue(cookieToVerify)
                return true
            } else {
                isValidating = false
                validationResult = (false, "Response did not contain user data")
                return false
            }
        } catch {
            isValidating = false
            validationResult = (false, "Error: \(error.localizedDescription)")
            return false
        }
    }
    
    // Function to create a request with authentication
    public func createAuthenticatedRequest(url: URL, cookieValue: String? = nil) -> URLRequest {
        // Use provided cookie value or the stored one
        let cookieValueToUse = cookieValue ?? self.cookieValue
        let cookieHeaderValue = "\(cookieNameKey)=\(cookieValueToUse)"
        
        var request = URLRequest(url: url)
        request.setValue(cookieHeaderValue, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    // Function to fetch subscription data from Stripe API
    func fetchSubscriptionData() async throws -> CursorSubscriptionData {
        print("Fetching subscription data from Stripe API...")
        
        let request = createAuthenticatedRequest(url: stripeAPIURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScrapingError.apiError("Failed to fetch subscription data from API")
        }
        
        // Log the raw API response for debugging
        print("--- Stripe API Response ---")
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
        print("-------------------------")
        
        // Try to parse the JSON response
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ScrapingError.parsingError("Invalid JSON format")
            }
            
            // Extract data from the JSON
            let membershipType = json["membershipType"] as? String
            let paymentId = json["paymentId"] as? String
            let daysRemainingOnTrial = json["daysRemainingOnTrial"] as? Int
            let subscriptionStatus = json["subscriptionStatus"] as? String
            
            // Log the data
            print("Subscription Data:")
            print("membershipType: \(membershipType ?? "nil")")
            print("subscriptionStatus: \(subscriptionStatus ?? "nil")")
            
            return CursorSubscriptionData(
                membershipType: membershipType,
                paymentId: paymentId,
                daysRemainingOnTrial: daysRemainingOnTrial,
                subscriptionStatus: subscriptionStatus
            )
        } catch {
            throw ScrapingError.parsingError("Failed to parse Stripe API response: \(error.localizedDescription)")
        }
    }
    
    // UPDATED: Use APIs with UserDefaults cookie and calculate usage
    func fetchUsageData() async throws -> CursorUsageData {
        print("Fetching usage data from API...")
        
        // Step 1: Verify auth is working by checking /api/auth/me
        let authRequest = createAuthenticatedRequest(url: authMeURL)
        let (authData, authResponse) = try await URLSession.shared.data(for: authRequest)
        
        guard let authHttpResponse = authResponse as? HTTPURLResponse, 
              authHttpResponse.statusCode == 200 else {
            throw ScrapingError.authenticationError
        }
        
        // Log auth response for debugging
        if let authJson = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
           let email = authJson["email"] as? String {
            print("Successfully authenticated as: \(email)")
        }
        
        // Step 2: Try to fetch subscription data
        do {
            let subscription = try await fetchSubscriptionData()
            self.subscriptionData = subscription
        } catch {
            print("Error fetching subscription data: \(error.localizedDescription)")
            // Continue even if we can't get subscription data
        }
        
        // Step 3: Fetch usage data from the API endpoint
        let usageRequest = createAuthenticatedRequest(url: usageAPIURL)
        let (usageData, usageResponse) = try await URLSession.shared.data(for: usageRequest)
        
        guard let usageHttpResponse = usageResponse as? HTTPURLResponse,
              usageHttpResponse.statusCode == 200 else {
            throw ScrapingError.apiError("Failed to fetch usage data from API")
        }
        
        // Log the raw API response for debugging
        print("--- Usage API Response ---")
        if let jsonString = String(data: usageData, encoding: .utf8) {
            print(jsonString)
        }
        print("-------------------------")
        
        // Try to parse the JSON response
        do {
            guard let json = try JSONSerialization.jsonObject(with: usageData) as? [String: Any] else {
                throw ScrapingError.parsingError("Invalid JSON format")
            }
            
            // Extract data from JSON based on the actual structure we received
            // Premium Model data (gpt-4)
            let premiumUsed: Int? = (json["gpt-4"] as? [String: Any])?["numRequests"] as? Int
            let premiumLimit: Int? = (json["gpt-4"] as? [String: Any])?["maxRequestUsage"] as? Int
            let numRequestsTotal: Int? = (json["gpt-4"] as? [String: Any])?["numRequestsTotal"] as? Int
            
            // Fast Model data (gpt-3.5-turbo)
            let fastUsed: Int? = (json["gpt-3.5-turbo"] as? [String: Any])?["numRequests"] as? Int
            
            // Calculate refresh days from startOfMonth
            let refreshDays: Int? = {
                if let startOfMonthStr = json["startOfMonth"] as? String {
                    print("startOfMonth string: \(startOfMonthStr)")
                    
                    // Use a formatter that handles fractional seconds
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    if let startOfMonth = formatter.date(from: startOfMonthStr) {
                        print("Parsed startOfMonth: \(startOfMonth)")
                        
                        // Calculate days until 30 days from startOfMonth
                        let renewalDate = Calendar.current.date(byAdding: .day, value: 30, to: startOfMonth) ?? Date()
                        print("renewalDate: \(renewalDate)")
                        
                        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
                        print("daysLeft: \(daysLeft)")
                        
                        return max(0, daysLeft) // Don't return negative days
                    } else {
                        print("Failed to parse ISO8601 date with fractional seconds, trying without...")
                        
                        // Fallback to basic formatter
                        let basicFormatter = ISO8601DateFormatter()
                        if let startOfMonth = basicFormatter.date(from: startOfMonthStr) {
                            print("Parsed with basic formatter: \(startOfMonth)")
                            
                            // Calculate days until 30 days from startOfMonth
                            let renewalDate = Calendar.current.date(byAdding: .day, value: 30, to: startOfMonth) ?? Date()
                            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
                            
                            return max(0, daysLeft) // Don't return negative days
                        }
                    }
                }
                print("Couldn't parse startOfMonth date")
                return nil
            }()
            
            // Log the computed values for debugging
            print("DEBUG VALUES:")
            print("refreshDays: \(refreshDays)")
            print("premiumUsed: \(premiumUsed)")
            print("premiumLimit: \(premiumLimit)")
            print("fastUsed: \(fastUsed)")
            print("numRequestsTotal: \(numRequestsTotal)")
            
            // Get current usage from API if available, otherwise calculate
            // For now, we rely on UserSettings.getMonthlyLimit() for the limit,
            // but this will be replaced by the actual hard limit from the API
            let currentUsageValue = json["currentUsage"] as? Double
            
            return CursorUsageData(
                refreshDays: refreshDays,
                premiumUsed: premiumUsed,
                premiumLimit: premiumLimit,
                fastUsed: fastUsed,
                currentUsage: currentUsageValue, // Store what API gives, or nil
                // usageLimit will be set after fetching from hardLimitAPIURL
                numRequestsTotal: numRequestsTotal
            )
        } catch {
            throw ScrapingError.parsingError("Failed to parse Usage API response: \(error.localizedDescription)")
        }
    }

    // New function to fetch the hard limit
    func fetchHardLimit() async throws -> Double? {
        print("Fetching hard limit from API...")
        var request = createAuthenticatedRequest(url: hardLimitAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Log the status code if it's not 200
            if let httpResponse = response as? HTTPURLResponse {
                print("Error fetching hard limit: Status code \(httpResponse.statusCode)")
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
            }
            throw ScrapingError.apiError("Failed to fetch hard limit. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        // Log the raw API response for debugging
        print("--- Hard Limit API Response ---")
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
        print("-----------------------------")

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hardLimit = json["hardLimit"] as? Double else {
                // Check if hardLimit is an Int and then cast
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let hardLimitInt = json["hardLimit"] as? Int {
                    print("Hard limit fetched as Int: \(hardLimitInt), converting to Double.")
                    return Double(hardLimitInt)
                }
                throw ScrapingError.parsingError("Invalid JSON format or missing 'hardLimit' key")
            }
            print("Hard limit fetched: \(hardLimit)")
            return hardLimit
        } catch {
            print("Error parsing hard limit response: \(error.localizedDescription)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response body that failed parsing: \(responseBody)")
            }
            throw ScrapingError.parsingError("Failed to parse Hard Limit API response: \(error.localizedDescription)")
        }
    }

    // New function to fetch the current month's invoice data (for currentUsage)
    func fetchCurrentMonthInvoice() async throws -> Double? {
        print("Fetching last completed month's invoice data from API...")

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        var targetMonth: Int
        var targetYear: Int

        if currentMonth == 1 { // If current month is January
            targetMonth = 12 // Target December
            targetYear = currentYear - 1 // Of the previous year
        } else {
            targetMonth = currentMonth - 1 // Target previous month
            targetYear = currentYear // Of the current year
        }

        let requestBody: [String: Any] = [
            "month": targetMonth, 
            "year": targetYear,
            "includeUsageEvents": true
        ]

        print("Request body for monthly invoice (fetching previous month: M=\(targetMonth), Y=\(targetYear)): \(requestBody)")

        var request = createAuthenticatedRequest(url: monthlyInvoiceAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                print("Error fetching monthly invoice: Status code \(httpResponse.statusCode)")
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
            }
            throw ScrapingError.apiError("Failed to fetch monthly invoice. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        print("--- Monthly Invoice API Response ---")
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
        print("----------------------------------")

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ScrapingError.parsingError("Invalid JSON format for monthly invoice")
            }
            
            // Updated parsing logic based on user-provided JSON structure
            if let itemsArray = json["items"] as? [[String: Any]] {
                var totalCents = 0
                for item in itemsArray {
                    if let cents = item["cents"] as? Int {
                        totalCents += cents
                    }
                }
                let totalAmount = Double(totalCents) / 100.0
                print("Current usage (calculated from invoice items array): \(totalAmount)")
                return totalAmount
            } else {
                print("Could not find 'items' array in monthly invoice response for current usage.")
                return nil 
            }
        } catch {
            print("Error parsing monthly invoice response: \(error.localizedDescription)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response body that failed parsing: \(responseBody)")
            }
            throw ScrapingError.parsingError("Failed to parse Monthly Invoice API response: \(error.localizedDescription)")
        }
    }
} 