//
//  AuthViewModel.swift - DEBUG VERSION
//  SOSync
//
//  Created by Islam Saadi on 22/06/2025.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var handle: AuthStateDidChangeListenerHandle?
    private let database = Database.database().reference()
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("🔍 Auth state changed - User: \(user?.uid ?? "nil")")
            self?.isAuthenticated = user != nil
            if let user = user {
                print("🔍 Calling fetchUserData for: \(user.uid)")
                self?.fetchUserData(userId: user.uid)
            } else {
                print("🔍 No user - setting currentUser to nil")
                self?.currentUser = nil
            }
        }
    }
    
    // ADD THIS: Public function for manual loading
    func loadCurrentUser(uid: String) async {
        print("🔍 loadCurrentUser called with UID: \(uid)")
        
        do {
            let snapshot = try await database.child("users").child(uid).getData()
            print("🔍 Database snapshot exists: \(snapshot.exists())")
            
            if snapshot.exists() {
                print("🔍 Raw data: \(snapshot.value ?? "no value")")
                
                guard let userData = snapshot.value as? [String: Any] else {
                    print("❌ Could not cast to [String: Any]")
                    return
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: userData)
                let user = try JSONDecoder().decode(User.self, from: jsonData)
                
                await MainActor.run {
                    self.currentUser = user
                    print("✅ User loaded successfully: \(user.username)")
                }
            } else {
                print("❌ User data doesn't exist in database")
            }
        } catch {
            print("❌ Error loading user: \(error)")
        }
    }
    
    func signUp(email: String, password: String, username: String, phoneNumber: String) async {
        
        await MainActor.run {
            isLoading    = true
            errorMessage = nil
        }

        do {
            // Check if username is already taken
            let usernameCheck = try await database.child("usernames").child(username.lowercased()).getData()
            if usernameCheck.exists() {
                throw AuthError.usernameTaken
            }
            
            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user object
            let newUser = User(
                id: result.user.uid,
                username: username,
                phoneNumber: phoneNumber,
                email: email,
                fcmToken: UserDefaults.standard.string(forKey: "FCMToken"),
                createdAt: Date().timeIntervalSince1970
            )
            
            // Save user to database
            try await database.child("users").child(result.user.uid).setValue(newUser.dictionary)
            
            // Save username mapping for quick lookup
            try await database.child("usernames").child(username.lowercased()).setValue(result.user.uid)
            
            // Save phone mapping for quick lookup
            let cleanPhone = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            try await database.child("phones").child(cleanPhone).setValue(result.user.uid)
            
            await MainActor.run {
                currentUser = newUser
                isLoading   = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading    = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // User data will be fetched by the auth listener
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // ENHANCED: Add debug prints to fetchUserData
    private func fetchUserData(userId: String) {
        print("🔍 fetchUserData called for userId: \(userId)")
        
        database.child("users").child(userId).observe(.value) { [weak self] snapshot in
            print("🔍 Database observer triggered")
            print("🔍 Snapshot exists: \(snapshot.exists())")
            print("🔍 Snapshot value: \(snapshot.value ?? "nil")")
            
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Could not cast snapshot.value to [String: Any]")
                print("❌ Actual type: \(type(of: snapshot.value))")
                return
            }
            
            print("🔍 Successfully cast to [String: Any]")
            
            guard let userData = try? JSONSerialization.data(withJSONObject: value) else {
                print("❌ Could not serialize to JSON data")
                return
            }
            
            print("🔍 Successfully serialized to JSON")
            
            guard let user = try? JSONDecoder().decode(User.self, from: userData) else {
                print("❌ Could not decode User object")
                return
            }
            
            print("✅ Successfully decoded user: \(user.username)")
            
            DispatchQueue.main.async {
                self?.currentUser = user
                print("✅ Set currentUser on main thread")
                
                // Update FCM token if needed
                if let fcmToken = UserDefaults.standard.string(forKey: "FCMToken"),
                   user.fcmToken != fcmToken {
                    self?.updateFCMToken(fcmToken)
                }
            }
        }
    }
    
    func updateFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        database.child("users").child(userId).child("fcmToken").setValue(token)
    }
    
    // MARK: - Search User with Validation
    func validateSearchQuery(_ query: String) -> SearchValidationResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        if trimmedQuery.isEmpty {
            return .invalid("Please enter a username or phone number")
        }
        
        if trimmedQuery.starts(with: "@") {
            // Username validation
            let username = String(trimmedQuery.dropFirst())
            
            if username.isEmpty {
                return .invalid("Please enter a username after @")
            }
            
            // Username should be alphanumeric and underscores only
            let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
            let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
            
            if !usernamePredicate.evaluate(with: username) {
                return .invalid("Username must be 3-20 characters long and contain only letters, numbers, and underscores")
            }
            
            return .valid(.username(username.lowercased()))
        } else {
            // Phone number validation
            let cleanPhone = trimmedQuery.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            
            if cleanPhone.isEmpty {
                return .invalid("Please enter a valid phone number or username starting with @")
            }
            
            if cleanPhone.count < 7 || cleanPhone.count > 15 {
                return .invalid("Phone number must be between 7-15 digits")
            }
            
            return .valid(.phone(cleanPhone))
        }
    }
    
    func searchUser(by query: String) async -> User? {
        let validationResult = validateSearchQuery(query)
        
        switch validationResult {
        case .invalid:
            return nil
        case .valid(let searchType):
            return await performSearch(searchType: searchType)
        }
    }
    
    private func performSearch(searchType: SearchType) async -> User? {
        do {
            let userId: String?
            
            switch searchType {
            case .username(let username):
                print("Searching for username: \(username)")
                let usernameSnapshot = try await database.child("usernames").child(username).getData()
                userId = usernameSnapshot.value as? String
                print("Found userId for username: \(userId ?? "nil")")
                
            case .phone(let phone):
                print("Searching for phone: \(phone)")
                let phoneSnapshot = try await database.child("phones").child(phone).getData()
                userId = phoneSnapshot.value as? String
                print("Found userId for phone: \(userId ?? "nil")")
            }
            
            guard let userId = userId else {
                print("No userId found")
                return nil
            }
            
            // Fetch user data
            print("Fetching user data for userId: \(userId)")
            let userSnapshot = try await database.child("users").child(userId).getData()
            
            guard let userDict = userSnapshot.value as? [String: Any] else {
                print("No user data found")
                return nil
            }
            
            print("User data found: \(userDict)")
            
            let jsonData = try JSONSerialization.data(withJSONObject: userDict)
            let user = try JSONDecoder().decode(User.self, from: jsonData)
            
            print("Successfully decoded user: \(user.username)")
            return user
            
        } catch {
            print("Error searching user: \(error)")
            return nil
        }
    }
}

// MARK: - Helper Types
enum SearchValidationResult {
    case valid(SearchType)
    case invalid(String)
}

enum SearchType {
    case username(String)
    case phone(String)
}

enum AuthError: LocalizedError {
    case usernameTaken
    
    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "This username is already taken. Please choose another one."
        }
    }
}
