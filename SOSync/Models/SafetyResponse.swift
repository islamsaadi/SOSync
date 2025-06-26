//
//  SafetyResponse.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//


// Safety Response model
struct SafetyResponse: Codable {
    let userId: String
    let status: SafetyResponseStatus
    let timestamp: Double
    let location: LocationData?
    let message: String?
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "status": status.rawValue,
            "timestamp": timestamp
        ]
        
        if let location = location {
            dict["location"] = location.dictionary
        }
        
        if let message = message {
            dict["message"] = message
        }
        
        return dict
    }
}


enum SafetyResponseStatus: String, Codable {
    case safe = "safe"
    case sos = "sos"
    case noResponse = "noResponse"
}
