import Foundation

// Modelo para la información de suscripción de Stripe
struct CursorSubscriptionData: Equatable {
    var membershipType: String?
    var paymentId: String?
    var daysRemainingOnTrial: Int?
    var subscriptionStatus: String?
    
    // Placeholder para cuando los datos no están disponibles
    static let placeholder = CursorSubscriptionData()
}

struct CursorUsageData: Equatable {
    // Using Optionals because scraping might fail or values might be missing
    var refreshDays: Int?
    var premiumUsed: Int?
    var premiumLimit: Int?
    var fastUsed: Int?
    // fastLimit is usually "No Limit", so maybe just store used count?
    var currentUsage: Double?
    var usageLimit: Double? // Changed to a simple stored property
    var numRequestsTotal: Int? // Total number of premium requests used (even beyond limit)

    // Add static example for previews or initial state
    static let example = CursorUsageData(
        refreshDays: 8,
        premiumUsed: 500,
        premiumLimit: 500,
        fastUsed: 130,
        currentUsage: 17.55,
        usageLimit: 50.0, // Added example value for usageLimit
        numRequestsTotal: 977
    )

    // Placeholder for when data is loading or not yet available
    // Ensure usageLimit is also part of the placeholder if needed, or keep it nil
    static let placeholder = CursorUsageData(usageLimit: nil) // Set to nil, API will populate
    
    // Get the total number of requests (from numRequestsTotal if available, otherwise use premiumUsed)
    func getTotalRequests() -> Int {
        // If we have numRequestsTotal, use that
        if let total = numRequestsTotal {
            return total
        }
        // Otherwise, use premiumUsed if available
        else if let used = premiumUsed {
            return used
        }
        // Default to 0 if nothing is available
        return 0
    }
    
    // Calculate the current usage based on requests over the limit
    // Corregido para usar el factor exacto observado en la facturación real
    func calculateCurrentUsage() -> Double {
        guard let total = numRequestsTotal, let limit = premiumLimit, total > limit else {
            return currentUsage ?? 0.0 // Return stored value or 0
        }
        
        let extraRequests = total - limit
        // Usando el factor más preciso basado en observaciones reales (20.35/507)
        let costPerRequest = 20.35 / 507.0 // Aproximadamente 0.0401 por request
        return Double(extraRequests) * costPerRequest
    }
} 