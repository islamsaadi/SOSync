//
//  User.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//


// User model
struct User: Identifiable, Codable {
    let id: String
    var username: String
    var phoneNumber: String
    var email: String
    var fcmToken: String?
    var groups: [String] = [] // Array of group IDs
    var createdAt: Double
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "username": username,
            "phoneNumber": phoneNumber,
            "email": email,
            "fcmToken": fcmToken ?? "",
            "groups": groups,
            "createdAt": createdAt
        ]
    }
}
