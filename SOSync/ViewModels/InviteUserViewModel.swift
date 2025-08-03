import Foundation
import SwiftUI

@MainActor
class InviteUserViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var foundUser: User?
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var validationError: String?
    
    private weak var authViewModel: AuthViewModel?
    private var group: SafetyGroup?
    
    var canSearch: Bool {
        !searchQuery.isEmpty && !isSearching && validationError == nil
    }
    
    func setupWith(authViewModel: AuthViewModel, group: SafetyGroup) {
        self.authViewModel = authViewModel
        self.group = group
    }
    
    func validateSearchQuery() {
        // Clear previous results when user types
        foundUser = nil
        searchError = nil
        
        guard let authViewModel = authViewModel else { return }
        
        // Validate input in real-time
        let validation = authViewModel.validateSearchQuery(searchQuery)
        switch validation {
        case .valid:
            validationError = nil
        case .invalid(let error):
            validationError = searchQuery.isEmpty ? nil : error
        }
    }
    
    func searchUser() async {
        guard let authViewModel = authViewModel,
              let group = group else { return }
        
        // Validate input before searching
        let validation = authViewModel.validateSearchQuery(searchQuery)
        switch validation {
        case .invalid(let error):
            searchError = error
            return
        case .valid:
            break
        }
        
        isSearching = true
        searchError = nil
        foundUser = nil
        
        let user = await authViewModel.searchUser(by: searchQuery)
        
        await MainActor.run {
            if let user = user {
                // Check if user is already in group
                if group.members.contains(user.id) {
                    searchError = "User is already a member of this group"
                    foundUser = nil
                } else if let pendingMembers = group.pendingMembers, pendingMembers.contains(user.id) {
                    // Safely unwrap and check pendingMembers
                    searchError = "User has already been invited"
                    foundUser = nil
                } else {
                    foundUser = user
                    searchError = nil
                }
            } else {
                searchError = "No user found with that username or phone number"
                foundUser = nil
            }
            isSearching = false
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        foundUser = nil
        searchError = nil
        validationError = nil
        isSearching = false
    }
}
