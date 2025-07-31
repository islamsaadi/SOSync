//
//  SafetyGroup.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

struct SafetyGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var adminId: String
    var members: [String] = []
    var pendingMembers: [String]? = [] // Made optional
    var safetyCheckInterval: Int = 30
    var sosInterval: Int = 5
    var lastSafetyCheck: Double?
    var currentStatus: SafetyGroupStatus = .normal
    var createdAt: Double
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "adminId": adminId,
            "members": members,
            "safetyCheckInterval": safetyCheckInterval,
            "sosInterval": sosInterval,
            "currentStatus": currentStatus.rawValue,
            "createdAt": createdAt
        ]
        
        // Only add optional fields if they have values
        if let pendingMembers = pendingMembers, !pendingMembers.isEmpty {
            dict["pendingMembers"] = pendingMembers
        }
        
        if let lastSafetyCheck = lastSafetyCheck {
            dict["lastSafetyCheck"] = lastSafetyCheck
        }
        
        return dict
    }
}

extension SafetyGroup: Equatable {
    static func == (lhs: SafetyGroup, rhs: SafetyGroup) -> Bool {
        return lhs.id == rhs.id &&
               lhs.currentStatus == rhs.currentStatus &&
               lhs.lastSafetyCheck == rhs.lastSafetyCheck &&
               lhs.name == rhs.name &&
               lhs.members == rhs.members
    }
}

enum SafetyGroupStatus: String, Codable, CaseIterable {
    case normal = "normal"
    case checkingStatus = "checkingStatus"
    case allSafe = "allSafe"
    case emergency = "emergency"
    
    var displayName: String {
        switch self {
        case .normal:        return "Normal"
        case .checkingStatus:return "Checking Status"
        case .allSafe:       return "All Safe"
        case .emergency:     return "Emergency"
        }
    }
    
    // Priority for sorting (higher = more important = shown first)
    var priority: Int {
        switch self {
        case .emergency:     return 4  // Most important
        case .checkingStatus:return 3  // Second most important
        case .allSafe:       return 2  // Third most important
        case .normal:        return 1  // Least important
        }
    }
}
