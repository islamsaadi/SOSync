//
//  User.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//


// User model
struct User: Identifiable, Codable {
    let id: String
    let username: String
    let phoneNumber: String
    let email: String
    let fcmToken: String?
    let createdAt: Double
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "username": username,
            "phoneNumber": phoneNumber,
            "email": email,
            "createdAt": createdAt
        ]
        
        if let fcmToken = fcmToken {
            dict["fcmToken"] = fcmToken
        }
        
        return dict
    }
}
