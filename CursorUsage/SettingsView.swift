import SwiftUI

struct SettingsView: View {
    @ObservedObject var scraper: CursorScraper
    @State private var cookieValue: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusField: Field?
    
    enum Field: Hashable {
        case cookie
    }
    
    init(scraper: CursorScraper) {
        self.scraper = scraper
        // Initialize the text field with the current cookie if available
        if let savedCookie = UserDefaults.standard.string(forKey: "cursor_cookie_value") {
            _cookieValue = State(initialValue: savedCookie)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title only
            HStack {
                Text("Cursor Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 5)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Authentication section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Authentication")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        Text("Enter your Cursor authentication cookie")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        // Text field with label
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WorkosCursorSessionToken:")
                                .font(.callout)
                                .foregroundColor(.primary)
                            
                            TextField("Paste cookie value here", text: $cookieValue, axis: .vertical)
                                .lineLimit(3)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .focused($focusField, equals: .cookie)
                                .submitLabel(.done)
                        }
                        .padding(.vertical, 5)
                        
                        // Validation status indicator
                        if scraper.isValidating {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Verifying...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 5)
                            }
                            .frame(height: 30)
                        } else if let result = scraper.validationResult {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                Text(result.message)
                                    .foregroundColor(result.success ? .green : .red)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 10)
                        }
                        
                        HStack {
                            Button("Clear Cookie") {
                                cookieValue = ""
                                UserDefaults.standard.removeObject(forKey: "cursor_cookie_value")
                                UserDefaults.standard.synchronize()
                                focusField = .cookie
                                // Also clear validation result if exists
                                scraper.validationResult = nil
                            }
                            .buttonStyle(.bordered)
                            .disabled(cookieValue.isEmpty || scraper.isValidating)
                            
                            Spacer()
                            
                            Button("Verify Cookie") {
                                // Only try to verify if there's a value
                                guard !cookieValue.isEmpty else { return }
                                
                                // Make async call to verify
                                Task {
                                    _ = await scraper.verifyCookie(cookieValue)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(cookieValue.isEmpty || scraper.isValidating)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Instructions card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to find your cookie:")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("1.")
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text("Login to cursor.com in your browser")
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("2.")
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text("Open Developer Tools (F12 or Cmd+Option+I)")
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("3.")
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text("Go to Application/Storage > Cookies > cursor.com")
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("4.")
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text("Find \"WorkosCursorSessionToken\" and copy its value")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 450, height: 550)
        .onAppear {
            // Delay focus slightly to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if cookieValue.isEmpty {
                    focusField = .cookie
                }
            }
        }
    }
}

#Preview {
    SettingsView(scraper: CursorScraper())
} 
