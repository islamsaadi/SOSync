//
//  LocationData.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//
import Foundation
import CoreLocation

// Location model
struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
    
    var dictionary: [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "address": address ?? ""
        ]
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
